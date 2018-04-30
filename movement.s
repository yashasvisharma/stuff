# debug constants
PRINT_INT_ADDR              = 0xffff0080
PRINT_FLOAT_ADDR            = 0xffff0084
PRINT_HEX_ADDR              = 0xffff0088

# spimbot memory-mapped I/O
VELOCITY                    = 0xffff0010
ANGLE                       = 0xffff0014
ANGLE_CONTROL               = 0xffff0018
BOT_X                       = 0xffff0020
BOT_Y                       = 0xffff0024
OTHER_BOT_X                 = 0xffff00a0
OTHER_BOT_Y                 = 0xffff00a4
TIMER                       = 0xffff001c
SCORES_REQUEST              = 0xffff1018

ASTEROID_MAP                = 0xffff0050
COLLECT_ASTEROID            = 0xffff00c8

STATION_LOC                 = 0xffff0054
DROPOFF_ASTEROID            = 0xffff005c

GET_ENERGY                  = 0xffff00c0
GET_CARGO                   = 0xffff00c4

REQUEST_PUZZLE              = 0xffff00d0
SUBMIT_SOLUTION             = 0xffff00d4

THROW_PUZZLE                = 0xffff00e0
UNFREEZE_BOT                = 0xffff00e8
CHECK_OTHER_FROZEN          = 0xffff101c

# interrupt constants
BONK_INT_MASK               = 0x1000
BONK_ACK                    = 0xffff0060

TIMER_INT_MASK              = 0x8000
TIMER_ACK                   = 0xffff006c

REQUEST_PUZZLE_INT_MASK     = 0x800
REQUEST_PUZZLE_ACK          = 0xffff00d8

STATION_ENTER_INT_MASK      = 0x400
STATION_ENTER_ACK           = 0xffff0058

STATION_EXIT_INT_MASK       = 0x2000
STATION_EXIT_ACK            = 0xffff0064

BOT_FREEZE_INT_MASK         = 0x4000
BOT_FREEZE_ACK              = 0xffff00e4


.data
.align 2
asteroid_map: .space 404

three:	.float	3.0
five:	.float	5.0
PI:	.float	3.141592
F180:	.float  180.0

# s0 = asteroid map
# s1 = &AsteroidMap.asteroids[0] = address to start of array
# t0 = favorite asteroid
# t2 = i
.text
main:
    # enable interrupts
    li      $t4, TIMER_INT_MASK # timer interrupt enable bit
    or      $t4, $t4, STATION_ENTER_INT_MASK    # st_enter interrupt bit
    or      $t4, $t4, STATION_EXIT_INT_MASK     # st_exit interrupt bit
    or      $t4, $t4, 1	        # global interrupt enable
    mtc0    $t4, $12            # set interrupt mask (Status register)

    # updating asteroid map
    la      $s0, asteroid_map
    sw      $s0, ASTEROID_MAP

    add     $s1, $s0, 4         # &(AsteroidMap.asteroids[0])
    move    $t0, $s1            # keep track of favorite asteroid
    #li      $t8, 0              # keep track of largest number of points

    li      $t2, 0              # i = 0

# s0 = asteroid map
# s1 = &AsteroidMap.asteroids[0] = address to start of array
# t0 = favorite asteroid
# t2 = i
# t3 = i offset, then x and y, then only x of asteroid being checked
# t4 = address of asteroid being checked
# t5 = points of asteroid being checked
# t6 = y of asteroid being checked
# t7 = 128
# t8 = favorite points
# t9 = length of the asteroid map, then current cargo
find_asteroid:
    lw      $t9, 0($s0)
    add     $t2, $t2, 1         # i++
    bge     $t2, $t9, move_to_asteroid     # br (i >= length)

    # checking the current asteroid in the array
    mul     $t3, $t2, 8         # i offset
    add     $t4, $s1, $t3       # &(AsteroidMap.asteroids[i])
    lw      $t5, 4($t4)         # AsteroidMap.asteroids->points
    #lw      $t6, 4($t0)         # favorite->points

    # getting x and y of asteroid being checked
    lw      $t3, 0($t0)         # x and y
    and     $t6, $t3, 65535     # masked 0x0000ffff to get y
    srl     $t3, $t3, 16        # shifted right by 16 to get x

    # check if x or y of new asteroid are out of bounds
    bge     $t3, 293, find_asteroid
    blt     $t3, 7, find_asteroid
    bge     $t6, 293, find_asteroid
    blt     $t6, 7, find_asteroid
    # check if asteroid points are greater than the limit
    bge     $t5, 128, find_asteroid
    # check if favorite points so far is greater than asteroid points
    lw      $t8, 4($t0)
    bge     $t8, $t5, find_asteroid  # br (largest_points >= points)

    # check if asteroid points exceed cargo capacity
    li      $t7, 128
    lw      $t9, GET_CARGO
    sub     $t7, $t7, $t9
    bge     $t5, $t7, find_asteroid  # br (points >= (128 - cargo))

    # set new favorite asteroid
    move    $t0, $t4
    #move    $t8, $t5

    # loop
    j       find_asteroid

# s0 = asteroid map
# s1 = &AsteroidMap.asteroids[0] = address to start of array
# t0 = favorite asteroid
# t1 = x of favorite asteroid
# t2 = y of favorite asteroid
# t3 = BOT_X, then new x direction
# t4 = BOT_Y, then new y direction
# t5 = angle direction
# t6 = 60, then 1, then 10
move_to_asteroid:
    # getting x and y of favorite asteroid
    lw      $t1, 0($t0)         # x and y
    and     $t2, $t1, 65535     # masked 0x0000ffff to get y
    srl     $t1, $t1, 16        # shifted right by 16 to get x

    # getting x and y of BOT
    lw      $t3, BOT_X
    lw      $t4, BOT_Y

    # favorite->x + 5 and favorite->y + 5
    add     $t1, $t1, 5
    add     $t2, $t2, 5

    # check if bot is not at the asteroid
    bgt     $t3, $t1, asteroid_loop
    bgt     $t4, $t2, asteroid_loop

    # favorite->x - 5 and favorite->y - 5
    sub     $t1, $t1, 10
    sub     $t2, $t2, 10

    # check if bot is not at the asteroid
    blt     $t3, $t1, asteroid_loop
    blt     $t4, $t2, asteroid_loop

    j       collect_asteroid

asteroid_loop:
    # getting x and y of favorite asteroid
    lw      $t1, 0($t0)         # x and y
    and     $t2, $t1, 65535     # masked 0x0000ffff to get y
    srl     $t1, $t1, 16        # shifted right by 16 to get x

    # getting x and y of BOT
    lw      $t3, BOT_X
    lw      $t4, BOT_Y

    # calculating x direction
    #li      $t6, -60
    #div     $t3, $t6
    #mflo    $t3
    #add     $t3, $t3, 5
    mul     $t3, $t3, 61        # multiply BOT_X by 61
    li      $t6, 60
    div     $t3, $t6            # divide by 60
    mflo    $t3
    sub     $t3, $t1, $t3       # subtract it from the asteroid x
    add     $t3, $t3, 5         # add 5

    lw      $t7, BOT_X
    li      $t8, 900
    div     $t8, $t7
    mflo    $t7
    #mul     $t7, $t3, -1

    mul     $t3, $t3, $t7
    #mul     $t3, $t3, 10

    # calculating y direction
    sub     $t4, $t2, $t4       # subtract BOT_Y from the asteroid y

    # saving registers to stack pointer
    sub     $sp, $sp, 20
    sw      $ra, 0($sp)
    sw      $t0, 4($sp)
    sw      $t1, 8($sp)
    sw      $a0, 12($sp)
    sw      $a1, 16($sp)

    # jump to arctan
    move    $a0, $t3
    move    $a1, $t4
    jal     sb_arctan

    # loading back registers from stack pointer
    lw      $ra, 0($sp)
    lw      $t0, 4($sp)
    lw      $t1, 8($sp)
    lw      $a0, 12($sp)
    lw      $a1, 16($sp)
    add     $sp, $sp, 20

    move    $t5, $v0
    sw      $t5, ANGLE
    li      $t6, 1
    sw      $t6, ANGLE_CONTROL

    # set velocity to 10
    # set angle direction
    lw      $t3, BOT_X
    li      $t6, 60
    div     $t3, $t6
    mflo    $t6
    mul     $t6, $t6, -1
    add     $t6, $t6, 5

    li      $t6, 10
    sw      $t6, VELOCITY

    j       move_to_asteroid

collect_asteroid:
    sw      $0, COLLECT_ASTEROID

# debugging purposes
#move_right:
    #lw      $t3, BOT_X
    #bge     $t3, 100, main

    #sw      $0, ANGLE
    #li      $t6, 1
    #sw      $t6, ANGLE_CONTROL
    #li      $t6, 10
    #sw      $t6, VELOCITY

    #j move_right

    #sw      $0, ANGLE
    #li      $t6, 1
    #sw      $t6, ANGLE_CONTROL
    #li      $t6, 10
    #sw      $t6, VELOCITY

    #j collect_asteroid

# s0 = asteroid map
# s1 = &AsteroidMap.asteroids[0] = address to start of array
# s3 = 1 if STATION is on the map
# t0 = favorite asteroid
# t1 = x of STATION
# t2 = y of STATION
# t3 = BOT_X, then new x direction
# t4 = BOT_Y, then new y direction
# t5 = ANGLE
# t6 = 60
# t7 = temp BOT_X, then multiply amount for x
# t8 = 900
# t9 = CARGO
move_to_station:
    # check if cargo is less than 80
    lw      $t9, GET_CARGO
    blt     $t9, 80, end

    # check if station is not on the map
    #beq     $s3, $0, end

    # getting x and y of station
    lw      $t1, STATION_LOC    # x and y
    and     $t2, $t1, 65535     # masked 0x0000ffff to get y
    srl     $t1, $t1, 16        # shifted right by 16 to get x

    # add to station location to have spimbot be closer
    add     $t1, 7
    add     $t2, 10

    # check if station is out of bounds of map
    beq     $s3, $0, end
    #bgt     $t1, 294, end
    #blt     $t1, 20, end
    #bgt     $t2, 294, end
    #blt     $t2, 20, end

station_loop:
    # getting x and y of BOT
    lw      $t3, BOT_X
    lw      $t4, BOT_Y

    # calculating x direction
    #li      $t6, -60
    #div     $t3, $t6
    #mflo    $t3
    #add     $t3, $t3, 5
    mul     $t3, $t3, 61        # multiply BOT_X by 61
    li      $t6, 60
    div     $t3, $t6            # divide by 60
    mflo    $t3
    sub     $t3, $t1, $t3       # subtract it from the STATION x
    add     $t3, $t3, 5         # add 5

    lw      $t7, BOT_X
    li      $t8, 900
    div     $t8, $t7
    mflo    $t7
    #mul     $t7, $t3, -1

    mul     $t3, $t3, $t7
    #mul     $t3, $t3, 10

    # calculating y direction
    sub     $t4, $t2, $t4       # subtract BOT_Y from the asteroid y

    # saving registers to stack pointer
    sub     $sp, $sp, 20
    sw      $ra, 0($sp)
    sw      $t0, 4($sp)
    sw      $t1, 8($sp)
    sw      $a0, 12($sp)
    sw      $a1, 16($sp)

    # jump to arctan
    move    $a0, $t3
    move    $a1, $t4
    jal     sb_arctan

    # loading back registers from stack pointer
    lw      $ra, 0($sp)
    lw      $t0, 4($sp)
    lw      $t1, 8($sp)
    lw      $a0, 12($sp)
    lw      $a1, 16($sp)
    add     $sp, $sp, 20

    move    $t5, $v0
    sw      $t5, ANGLE
    li      $t6, 1
    sw      $t6, ANGLE_CONTROL

    # set velocity to 10
    # set angle direction
    lw      $t3, BOT_X
    li      $t6, 60
    div     $t3, $t6
    mflo    $t6
    mul     $t6, $t6, -1
    add     $t6, $t6, 5

    li      $t6, 10
    sw      $t6, VELOCITY



    # getting x and y of station
    lw      $t1, STATION_LOC    # x and y
    and     $t2, $t1, 65535     # masked 0x0000ffff to get y
    srl     $t1, $t1, 16        # shifted right by 16 to get x\

    lw      $t3, BOT_X
    lw      $t4, BOT_Y

    # checks if bot is on the station
    # STATION_X + 5 and STATION_Y + 5
    add     $t1, $t1, 10
    add     $t2, $t2, 10

    # check if bot is not at the asteroid
    bgt     $t3, $t1, move_to_station
    bgt     $t4, $t2, move_to_station

    # STATION_X - 5 and STATION_Y - 5
    sub     $t1, $t1, 20
    sub     $t2, $t2, 20

    # check if bot is not at the asteroid
    blt     $t3, $t1, move_to_station
    blt     $t4, $t2, move_to_station

    #j       move_to_station

dropoff:
    sw      $0, DROPOFF_ASTEROID
    #j       end
end:
# note that we infinite loop to avoid stopping the simulation early
j       main

sb_arctan:
	li	$v0, 0		# angle = 0;

	abs	$t0, $a0	# get absolute values
	abs	$t1, $a1
	ble	$t1, $t0, no_TURN_90

	## if (abs(y) > abs(x)) { rotate 90 degrees }
	move	$t0, $a1	# int temp = y;
	neg	$a1, $a0	# y = -x;
	move	$a0, $t0	# x = temp;
	li	$v0, 90		# angle = 90;

no_TURN_90:
	bgez	$a0, pos_x 	# skip if (x >= 0)

	## if (x < 0)
	add	$v0, $v0, 180	# angle += 180;

pos_x:
	mtc1	$a0, $f0
	mtc1	$a1, $f1
	cvt.s.w $f0, $f0	# convert from ints to floats
	cvt.s.w $f1, $f1

	div.s	$f0, $f1, $f0	# float v = (float) y / (float) x;

	mul.s	$f1, $f0, $f0	# v^^2
	mul.s	$f2, $f1, $f0	# v^^3
	l.s	$f3, three	# load 3.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five	# load 5.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

	l.s	$f8, PI		# load PI
	div.s	$f6, $f6, $f8	# value / PI
	l.s	$f7, F180	# load 180.0
	mul.s	$f6, $f6, $f7	# 180.0 * value / PI

	cvt.w.s $f6, $f6	# convert "delta" back to integer
	mfc1	$t0, $f6
	add	$v0, $v0, $t0	# angle += delta

	jr 	$ra

.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers
	sw	$a1, 4($k0)		# by storing them to a global variable

	mfc0	$k0, $13		# Get Cause register
	srl	$a0, $k0, 2
	and	$a0, $a0, 0xf		# ExcCode field
	bne	$a0, 0, non_intrpt

interrupt_dispatch:			# Interrupt:
	mfc0	$k0, $13		# Get Cause register, again
	beq	$k0, 0, done		# handled all outstanding interrupts

	and	$a0, $k0, STATION_ENTER_INT_MASK	# is there a bonk interrupt?
	bne	$a0, 0, enter_interrupt

	and	$a0, $k0, TIMER_INT_MASK	# is there a timer interrupt?
	bne	$a0, 0, timer_interrupt

    and	$a0, $k0, STATION_EXIT_INT_MASK	# is there a timer interrupt?
	bne	$a0, 0, exit_interrupt

	# add dispatch for other interrupt types here.

	li	$v0, PRINT_INT_ADDR	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall
	j	done

enter_interrupt:
    sw      $a1, 0xffff0058($zero)   # acknowledge interrupt
    li      $s3, 1

    j       interrupt_dispatch
exit_interrupt:
    sw      $a1, 0xffff0064($zero)   # acknowledge interrupt
    li      $s3, 0

    j       interrupt_dispatch
timer_interrupt:
	sw	$a1, TIMER_INT_ACK		# acknowledge interrupt

	#li	$t0, 90			# ???
	#sw	$t0, ANGLE		# ???
	#sw	$zero, ANGLE_CONTROL	# ???

	lw	$v0, TIMER		# current time
	add	$v0, $v0, 50000
	sw	$v0, TIMER		# request timer in 50000 cycles

	j	interrupt_dispatch	# see if other interrupts are waiting
non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_INT_ADDR
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done
done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at
	eret
