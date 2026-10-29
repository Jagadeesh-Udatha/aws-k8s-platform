#!/usr/bin/env bash
# End-to-end checks against the services running in the kind cluster:
#   PayFlow: token -> open two accounts -> idempotent transfer (and its replay) -> event lands on Kafka.
#   Telemetry: GPS event produced to Kafka -> vehicle state in MongoDB via the API -> overspeed alert.
set -euo pipefail
NS=${NS:-platform}
K="kubectl -n $NS"
fail() { echo "FAIL: $*" >&2; exit 1; }

$K port-forward svc/payflow-ledger 18080:80 >/dev/null 2>&1 &
PF1=$!
$K port-forward svc/telemetry-stream 18081:80 >/dev/null 2>&1 &
PF2=$!
trap 'kill $PF1 $PF2 2>/dev/null || true' EXIT
for p in 18080 18081; do
  for _ in $(seq 30); do curl -fs "localhost:$p/actuator/health/readiness" >/dev/null && break; sleep 1; done
done

echo "== PayFlow"
API=localhost:18080
TOKEN=$(curl -fsS -X POST "$API/api/auth/token" -H 'Content-Type: application/json' \
  -d '{"username":"ops","password":"ops-kind-password"}' | jq -r .accessToken)
[ -n "$TOKEN" ] && [ "$TOKEN" != null ] || fail "no token"
AUTH=(-H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json')

A=$(curl -fsS -X POST "$API/api/accounts" "${AUTH[@]}" -d '{"ownerName":"Asha","currency":"INR","openingDeposit":1000.00}' | jq -r .id)
B=$(curl -fsS -X POST "$API/api/accounts" "${AUTH[@]}" -d '{"ownerName":"Ravi","currency":"INR","openingDeposit":0}' | jq -r .id)
echo "accounts $A $B"

BODY=$(jq -nc --arg a "$A" --arg b "$B" '{sourceAccountId:$a,targetAccountId:$b,amount:250.00,reference:"smoke"}')
KEY="smoke-$(date +%s)"
CODE=$(curl -s -o /tmp/pay1.json -w '%{http_code}' -X POST "$API/api/payments" "${AUTH[@]}" -H "Idempotency-Key: $KEY" -d "$BODY")
[ "$CODE" = 201 ] || fail "first transfer returned $CODE: $(cat /tmp/pay1.json)"
CODE=$(curl -s -o /tmp/pay2.json -w '%{http_code}' -X POST "$API/api/payments" "${AUTH[@]}" -H "Idempotency-Key: $KEY" -d "$BODY")
[ "$CODE" = 200 ] && [ "$(jq -r .replayed /tmp/pay2.json)" = true ] || fail "retry was not a replay ($CODE)"
[ "$(jq -r .id /tmp/pay1.json)" = "$(jq -r .id /tmp/pay2.json)" ] || fail "retry created a second payment"
echo "transfer 201, retry replayed with the same payment id"

# The outbox relay (FOR UPDATE SKIP LOCKED on MySQL) must have published the event.
EVENTS=$($K exec deploy/kafka -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic payments.events --from-beginning --timeout-ms 30000 2>/dev/null || true)
echo "$EVENTS" | grep -q "$(jq -r .id /tmp/pay1.json)" || fail "payment event not found on payments.events"
echo "payment event published to Kafka"

echo "== Telemetry"
TEL=localhost:18081
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EVENT=$(jq -nc --arg ts "$NOW" '{eventId:"smoke-1",vehicleId:"KA01AB1234",ts:$ts,lat:12.9716,lon:77.5946,speedKph:96.5,heading:90}')
echo "KA01AB1234|$EVENT" | $K exec -i deploy/kafka -- /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic telemetry.raw --property parse.key=true --property key.separator='|'

for _ in $(seq 40); do
  curl -fs "$TEL/api/vehicles/KA01AB1234" -o /tmp/vehicle.json && break; sleep 1
done
[ -s /tmp/vehicle.json ] || fail "vehicle state never appeared"
echo "vehicle state: $(cat /tmp/vehicle.json)"

for _ in $(seq 30); do
  curl -fs "$TEL/api/alerts?vehicleId=KA01AB1234" | grep -q OVERSPEED && { echo "overspeed alert stored"; break; }
  sleep 1
done
curl -fs "$TEL/api/alerts?vehicleId=KA01AB1234" | grep -q OVERSPEED || fail "no overspeed alert"

echo "SMOKE OK"
