#!/bin/bash

case "$1" in
	star_wars)
		beep -l 350 -f 392 -D 100 --new -l 350 -f 392 -D 100 --new -l 350 -f 392 -D 100 --new -l 250 -f 311.1 -D 100 --new -l 25 -f 466.2 -D 100 --new -l 350 -f 392 -D 100 --new -l 250 -f 311.1 -D 100 --new -l 25 -f 466.2 -D 100 --new -l 700 -f 392 -D 100 --new -l 350 -f 587.32 -D 100 --new -l 350 -f 587.32 -D 100 --new -l 350 -f 587.32 -D 100 --new -l 250 -f 622.26 -D 100 --new -l 25 -f 466.2 -D 100 --new -l 350 -f 369.99 -D 100 --new -l 250 -f 311.1 -D 100 --new -l 25 -f 466.2 -D 100 --new -l 700 -f 392 -D 100 --new -l 350 -f 784 -D 100 --new -l 250 -f 392 -D 100 --new -l 25 -f 392 -D 100 --new -l 350 -f 784 -D 100 --new -l 250 -f 739.98 -D 100 --new -l 25 -f 698.46 -D 100 --new -l 25 -f 659.26 -D 100 --new -l 25 -f 622.26 -D 100 --new -l 50 -f 659.26 -D 400 --new -l 25 -f 415.3 -D 200 --new -l 350 -f 554.36 -D 100 --new -l 250 -f 523.25 -D 100 --new -l 25 -f 493.88 -D 100 --new -l 25 -f 466.16 -D 100 --new -l 25 -f 440 -D 100 --new -l 50 -f 466.16 -D 400 --new -l 25 -f 311.13 -D 200 --new -l 350 -f 369.99 -D 100 --new -l 250 -f 311.13 -D 100 --new -l 25 -f 392 -D 100 --new -l 350 -f 466.16 -D 100 --new -l 250 -f 392 -D 100 --new -l 25 -f 466.16 -D 100 --new -l 700 -f 587.32 -D 100 --new -l 350 -f 784 -D 100 --new -l 250 -f 392 -D 100 --new -l 25 -f 392 -D 100 --new -l 350 -f 784 -D 100 --new -l 250 -f 739.98 -D 100 --new -l 25 -f 698.46 -D 100 --new -l 25 -f 659.26 -D 100 --new -l 25 -f 622.26 -D 100 --new -l 50 -f 659.26 -D 400 --new -l 25 -f 415.3 -D 200 --new -l 350 -f 554.36 -D 100 --new -l 250 -f 523.25 -D 100 --new -l 25 -f 493.88 -D 100 --new -l 25 -f 466.16 -D 100 --new -l 25 -f 440 -D 100 --new -l 50 -f 466.16 -D 400 --new -l 25 -f 311.13 -D 200 --new -l 350 -f 392 -D 100 --new -l 250 -f 311.13 -D 100 --new -l 25 -f 466.16 -D 100 --new -l 300 -f 392.00 -D 150 --new -l 250 -f 311.13 -D 100 --new -l 25 -f 466.16 -D 100 --new -l 700 -f 392
	;;
	elise)
		beep -f 659 120  #  Treble E
		# beep -f 1 60
		beep -f 622 120  #  Treble D#

		beep -f 659 120  #  Treble E
		beep -f 622 120  #  Treble D#
		beep -f 659 120  #  Treble E
		beep -f 94 120   #  Treble B
		beep -f 587 120  #  Treble D
		beep -f 523 120  #  Treble C

		beep -f 440 120  #  Treble A
		beep -f 262 120  #  Middle C
		beep -f 330 120  #  Treble E
		beep -f 440 120  #  Treble A

		beep -f 494 120  #  Treble B
		beep -f 330 120  #  Treble E
		beep -f 415 120  #  Treble G#
		beep -f 494 120  #  Treble B

		beep -f 523 120  #  Treble C
		beep -f 330 120  #  Treble E
		beep -f 659 120  #  Treble E
		beep -f 622 120  #  Treble D#

		beep -f 659 120  #  Treble E
		beep -f 622 120  #  Treble D#
		beep -f 659 120  #  Treble E
		beep -f 494 120  #  Treble B
		beep -f 587 120  #  Treble D
		beep -f 523 120  #  Treble C

		beep -f 440 120  #  Treble A
		beep -f 262 120  #  Middle C
		beep -f 330 120  #  Treble E
		beep -f 440 120  #  Treble A

		beep -f 494 120  #  Treble B
		beep -f 330 120  #  Treble E
		beep -f 523 120  #  Treble C
		beep -f 494 120  #  Treble B
		beep -f 440 120  #  Treble A
	;;
	
	*)

	;;
esac
