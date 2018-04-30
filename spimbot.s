# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

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
# strings for printing
struct_msg:     .asciiz "Solution struct: "
len_msg:        .asciiz "  length = "
counts_msg:     .asciiz "  counts = {"
comma_msg:      .asciiz ", "
brkt_msg:       .asciiz "}"



# structs
lines:          .word   2       start_pos       end_pos
start_pos:      .word   2       10
end_pos:        .word   22      14

canvas:         .word   0       0       0       canv
canv:           .space  1024

solution:       .word   2       counts
counts:         .space  8
puzzle_data:    .space 1024

.text
MAIN_STK_SPC = 32
main:
        li	    $t1 , TIMER_INT_MASK		            # timer interrupt enable bit
      	or	    $t1 , $t1 , STATION_ENTER_INT_MASK	  # station enter interrupt bit
        or	    $t1 , $t1 , STATION_EXIT_INT_MASK	  # station exit interrupt bit
        or      $t1 , $t1 , REQUEST_PUZZLE_INT_MASK
      	or	    $t1 , $t1, 1		                    # global interrupt enable
      	mtc0	  $t1 , $12		                        # set interrupt mask (Status register)
        li      $s4 , 2
        la      $s0 , puzzle_data

program_start:

        sw      $s0 , REQUEST_PUZZLE
puzzle_begin:
        bne     $s4 , 1 , puzzle_begin
        la      $s5 , puzzle_data
        lw      $a0 , 16($s5)
        lw      $a1 , 0($s5)
        la      $t1 , GET_ENERGY
        lw      $t1 , 0($t1)
        #blt     $t1 , 200 , main
        sub     $sp , $sp , 40
        sw      $t0 , 0($sp)
        sw      $t1 , 0($sp)
        sw      $t2 , 0($sp)
        sw      $t3 , 0($sp)
        sw      $t4 , 0($sp)
        sw      $t5 , 0($sp)
        sw      $t6 , 0($sp)
        sw      $t7 , 0($sp)
        sw      $s0 , 0($sp)      #anything else that needs to be stored
        sw      $s1 , 0($sp)

        add     $t0 , $0 , 0      #unsigned int i = 0
loop_puzzle:
        lw      $t1 , 0($a0)
        bge     $t0 , $t1 , end_puzzle   #i < lines->num_lines
        lw      $t1 , 4($a0)      #line[0]
        mul     $t3 , $t0 , 4     #get the offset of the array index for start_pos
        add     $t1 , $t1 , $t3
        lw      $t1 , 0($t1)

        lw      $t2 , 8($a0)      #repeated for end_pos
        add     $t2 , $t2 , $t3
        lw      $t2 , 0($t2)

        sub     $sp , $sp , 20    #save relevant variables
        sw      $t0 , 0($sp)
        sw      $a0 , 4($sp)
        sw      $a1 , 8($sp)
        sw      $ra , 16($sp)

        move    $a2 , $a1         #prepare for function call
        move    $a1 , $t2
        move    $a0 , $t1
        j     draw_line         #call draw_line
come_back1:

        lw      $t0 , 0($sp)      #return variables back
        lw      $a0 , 4($sp)
        lw      $a1 , 8($sp)
        lw      $ra , 16($sp)

        li      $t1 , 2           #arithmatic for count_disjoint_regions_step parameters
        div     $t0 , $t1
        mfhi    $t2
        add     $t2 , $t2 , 65

        move    $a0 , $t2         #prepare for function call
        move    $a1 , $a1
        j     count_disjoint_regions_step
come_back2:
        move    $t1 , $v0         #store return value from function

        lw      $t0 , 0($sp)      #return variables after function call
        lw      $a0 , 4($sp)
        lw      $a1 , 8($sp)
        lw      $ra , 16($sp)

        add     $sp , $sp, 20      #deallocate stack pointer

        #write $t1 into wherever it goes
        move    $s3 , $t0
        add     $t0 , $t0 , 1       #for loop i increment
        j       loop_puzzle                #loop again
draw_line:
        lw      $t0 , 4($a2)          #width = canvas -> width
        add     $t1 , $0 , 1          #step_size = 1
        sub     $t2 , $a1 , $a0       #end_pos - start_pos
        blt     $t2 , $t0 , post_if_draw   #end_pos - start_pos >= width
        add     $t1 , $t0 , $0        #step_size = width
post_if_draw:
        add     $t2 , $a0 , 0         #pos = start_pos
        add     $t3 , $a1 , $t1       #end_pos + step_size
        lw      $t6 , 12($a2)         #get the start of canvas
loop_draw:
        beq     $t2 , $t3 , end_draw       #pos != end_pos + step_size
        div     $t2 , $t0
        mflo    $t5                   #pos / width
        mfhi    $t7                   #pos % width
        mul     $t5 , $t5 , 4         #multiply by 4 to get offset
        add     $t4 , $t6 , $t5       #add start to offset
        lw      $t4 , 0($t4)          #starting address of row
        add     $t4 , $t4 , $t7       #get the address of the the pixel
        lb      $t5 , 8($a2)
        sb      $t5 , 0($t4)          #canvas -> canvas [pos / width][pos % width] = canvas -> pattern
        add     $t2 , $t2 , $t1       #pos += step_size
        j       loop_draw
end_draw:
        j      come_back1
count_disjoint_regions_step:
        add     $t0 , $0 , 0           # $t0 = region_count
        add     $t1 , $0 , 0           # $t1 = row
for_level_1:
        lw      $t3 , 0($a1)           # store height temporaily
        bge     $t1 , $t3, return      # if col < canvas -> width end for loop
        add     $t2 , $0 , 0           # $t2 = col
for_level_2:
        lw      $t3 , 4($a1)           # store width temporaily
        bge     $t2 , $t3 , end_outer  # if col > width end for loop
        mul     $t4 , $t1 , 4          # get offset from start
        lw      $t5 , 12($a1)          # store address of canvas -> canvas
        add     $t6 , $t5 , $t4        # add the offset to the start of the array
        lw      $t6 , 0($t6)           # derefernce pointer
        add     $t6 , $t6 , $t2        # get the address of the the pixel
        lb      $t7 , 0($t6)           # store the char at [row][col] in $t7

        lb      $t3 , 8($a1)           # store pattern temporaily
        beq     $t7 , $t3 , end_inner  # if curr_char != pattern
        beq     $t7 , $a0 , end_inner  # and curr_char != marker
        add     $t0 , $t0 , 1          # increase region_count

        sub     $sp , $sp , 28          # save caller saved registers
        sw      $ra , 0($sp)
        sb      $a0 , 4($sp)
        sw      $a1 , 8($sp)
        sw      $t0 , 12($sp)
        sw      $t1 , 16($sp)
        sw      $t2 , 20($sp)
        sb      $t7 , 24($sp)
                                       # Call to flood_fill
        move    $a2 , $a0              # rearange a registers for call to flood_fill
        move    $a3 , $a1
        move    $a0 , $t1
        move    $a1 , $t2
        j     flood_fill             # flood_fill(row, col, marker, canvas)
come_back3:
        lw      $ra , 0($sp)
        lb      $a0 , 4($sp)           # replace a registers after call
        lw      $a1 , 8($sp)
        lw      $t0 , 12($sp)
        lw      $t1 , 16($sp)
        lw      $t2 , 20($sp)
        lb      $t7 , 24($sp)
        add     $sp , $sp , 28
end_inner:
        add     $t2 , $t2 , 1          # col ++
        j       for_level_2            # next iteration of inner loop
end_outer:
        add     $t1 , $t1 , 1          # row ++
        j       for_level_1            # next iteration of outer loop
return:
        move    $v0 , $t0              # assign return value
        j      come_back2                    # return to where program was called
flood_fill:
        blt     $a0 , $0 , end_ff      # if row < 0
        blt     $a1 , $0 , end_ff      # or if col < 0
        lw      $t1 , 0($a3)        # store temp for canvas -> height
        bge     $a0 , $t1 , end_ff     # or if row >= canvas -> height
        lw      $t1 , 4($a3)        # store temp canvas -> width
        bge     $a1 , $t1 , end_ff     # or if col >= canvas -> width

        mul     $t1 , $a0 , 4       # get offset from start
        lw      $t2 , 12($a3)       # store address of canvas -> canvas
        add     $t3 , $t2 , $t1     # add the offset to the start of the array
        lw      $t3 , 0($t3)        # derefernce pointer
        add     $t3 , $t3 , $a1     # get the address of the the pixel
        lb      $t4 , 0($t3)        # store the char at [row][col] in $t4

        lb      $t1 , 8($a3)        # store canvas -> pattern
        beq     $t4 , $t1 , end_ff     # one and condition isn't met, end
        beq     $t4 , $a2 , end_ff     # if the other condition isn't met, end
        sb      $a2 , 0($t3)        # store marker in canvas[row][col]

        sub     $sp , $sp , 12
        sw      $ra , 0($sp)
        sw      $a0 , 4($sp)
        sw      $a1 , 8($sp)

        sub     $a0 , $a0 , 1      # row -1 , col
        j     flood_fill
        lw      $a0 , 4($sp)

        add     $a1 , $a1 , 1      # row , col + 1
        j     flood_fill
        lw      $a1 , 8($sp)

        add     $a0 , $a0 , 1      # row + 1 , col
        j     flood_fill
        lw      $a0 , 4($sp)

        sub     $a1 , $a1 , 1      #row , col + 1
        j     flood_fill
        lw      $a1 , 8($sp)

        lw      $ra , 0($sp)
        add     $sp , $sp , 12
end_ff:
        j      come_back3
end_puzzle:
        lw      $t0 , 0($sp)
        lw      $t1 , 0($sp)
        lw      $t2 , 0($sp)
        lw      $t3 , 0($sp)
        lw      $t4 , 0($sp)
        lw      $t5 , 0($sp)
        lw      $t6 , 0($sp)
        lw      $t7 , 0($sp)
        lw      $s0 , 0($sp)      #anything else that needs to be stored
        lw      $s1 , 0($sp)
        add     $sp , $sp , 40
        sw      $s3 , SUBMIT_SOLUTION
        li      $s4 , 0
        j       program_start

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

      	and	$a0, $k0, STATION_ENTER_INT_MASK	# is there a timer interrupt?
      	bne	$a0, 0, station_interupt

        and	$a0, $k0, STATION_EXIT_INT_MASK	# is there a timer interrupt?
      	bne	$a0, 0, station_interupt_exit

        and	$a0, $k0, REQUEST_PUZZLE_INT_MASK 	# is there a timer interrupt?
      	bne	$a0, 0, request_puzzle

        and	$a0, $k0, TIMER_INT_MASK 	# is there a timer interrupt?
      	bne	$a0, 0, timer_interrupt

      	# add dispatch for other interrupt types here.

      	li	$v0, PRINT_STRING	# Unhandled interrupt types
      	la	$a0, unhandled_str
      	syscall
      	j	done

timer_interrupt:
      	sw	$a1, TIMER_ACK		# acknowledge interrupt

      	lw	$v0, TIMER		# current time
      	add	$v0, $v0, 50000
      	sw	$v0, TIMER		# request timer in 50000 cycles
        j interrupt_dispatch
request_puzzle:
        sw	    $a1 , REQUEST_PUZZLE_ACK		# acknowledge interrupt
        li      $s4 , 1
        j       interrupt_dispatch
station_interupt:
			sw	    $a1 , STATION_ENTER_ACK		# acknowledge interrupt
      li      $s7 , 1
      j       interrupt_dispatch

end_intur:
  		j	      interrupt_dispatch	# see if other interrupts are waiting

station_interupt_exit:
  		sw	    $a1 , STATION_EXIT_ACK		# acknowledge interrupt
      #li      $s7 , 0
  		j	      interrupt_dispatch	# see if other interrupts are waiting

non_intrpt:				# was some non-interrupt
    		li	$v0, PRINT_STRING
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

