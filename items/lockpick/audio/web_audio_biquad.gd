class_name WebAudioBiquad
extends RefCounted
## A biquad filter with the Web Audio API's BiquadFilterNode coefficients (the RBJ cookbook with
## Web Audio's Q conventions: lowpass and highpass take Q in dB, bandpass takes it linearly),
## direct form I. The same formulas as `tools/sfx_gen/lockpick_sfx.py`, so sounds synthesised live
## match the baked ones ([ADR 0108](../../../design/decisions/0108-lockpick-sounds.md)).

enum Type { LOWPASS, HIGHPASS, BANDPASS }

## Coefficients normalised by a0.
var b0: float = 1.0
var b1: float = 0.0
var b2: float = 0.0
var a1: float = 0.0
var a2: float = 0.0

var _x1: float = 0.0
var _x2: float = 0.0
var _y1: float = 0.0
var _y2: float = 0.0


## Sets the coefficients; the filter state is kept (as when a Web Audio filter's frequency moves).
func configure(type: Type, frequency: float, q: float, sample_rate: float) -> void:
	var w0 := TAU * frequency / sample_rate
	var cos_w0 := cos(w0)
	var alpha: float
	var n0: float
	var n1: float
	var n2: float
	match type:
		Type.BANDPASS:
			alpha = sin(w0) / (2.0 * q)
			n0 = alpha
			n1 = 0.0
			n2 = -alpha
		Type.LOWPASS:
			alpha = sin(w0) / (2.0 * pow(10.0, q / 20.0))
			n0 = (1.0 - cos_w0) / 2.0
			n1 = 1.0 - cos_w0
			n2 = n0
		_:
			alpha = sin(w0) / (2.0 * pow(10.0, q / 20.0))
			n0 = (1.0 + cos_w0) / 2.0
			n1 = -(1.0 + cos_w0)
			n2 = n0
	var a0 := 1.0 + alpha
	b0 = n0 / a0
	b1 = n1 / a0
	b2 = n2 / a0
	a1 = -2.0 * cos_w0 / a0
	a2 = (1.0 - alpha) / a0


func reset() -> void:
	_x1 = 0.0
	_x2 = 0.0
	_y1 = 0.0
	_y2 = 0.0


## Filters one sample.
func process(x: float) -> float:
	var y := b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2
	_x2 = _x1
	_x1 = x
	_y2 = _y1
	_y1 = y
	return y


## Filters `buffer[from..to)` in place (one call per block keeps per-sample calls out of hot loops).
func process_range(buffer: PackedFloat32Array, from: int, to: int) -> void:
	var x1 := _x1
	var x2 := _x2
	var y1 := _y1
	var y2 := _y2
	for i in range(from, to):
		var x := buffer[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buffer[i] = y
	_x1 = x1
	_x2 = x2
	_y1 = y1
	_y2 = y2
