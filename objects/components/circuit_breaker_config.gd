class_name CircuitBreakerConfig
extends Resource
## Tuning of a CircuitBreaker (ADR 0066, ADR 0138): `objects/components/circuit_breaker.tres`.

## Loudness of the clunk on every throw (audible metres, noise stimulus).
@export var noise_loudness: float = 6.0
