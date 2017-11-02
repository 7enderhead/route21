#lang racket

(require threading)
(require "data-defs.rkt")
(require "util.rkt")

; integer range for slider controls
(define slider-max 16960)
(define slider-min (- slider-max))

(define (slider->value slider-value min-value max-value)
  (map-range slider-value slider-min slider-max min-value max-value))

(define (slider->lon stops value)
  (slider->value value (min-lon stops) (max-lon stops)))

(define (slider->lat stops value)
  (slider->value value (min-lat stops) (max-lat stops)))

(define (slider-value->label converter prefix value)
  (format "~a: ~a" prefix (~> value
                              (converter)
                              coord->string)))

(define (lon-slider-value->label stops prefix value)
  (slider-value->label (slider->lon stops) prefix value))

(define (lat-slider-value->label stops prefix value)
  (slider-value->label (slider->lat stops) prefix value))

(define (make-min-lon-label stops value)
  (lon-slider-value->label stops "min. Lon." value))
  
(define (make-max-lon-label stops value)
  (lon-slider-value->label stops "max. Lon." value))
  
(define (make-min-lat-label stops value)
  (lat-slider-value->label stops "min. Lat." value))
  
(define (make-max-lat-label stops value)
  (lat-slider-value->label stops "max. Lat." value))

(provide (all-defined-out))