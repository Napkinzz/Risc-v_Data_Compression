#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2017 University of Alberta
# Copyright 2017 Kristen Newbury
# Copyright 2019 Abdulrahman Alattas
# Copyright 2020 Quinn Pham
# Copyright 2021 Jason Sommerville
#
# This software is distributed to students in the course
# CMPUT 229 - Computer Organization and Architecture I at the University of
# Alberta, Canada.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the disclaimer below in the documentation
#    and/or other materials provided with the distribution.
#
# 2. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#-------------------------------
# Lab_DataCompression Common File
# Author: Jason Sommerville
# Date: June 11, 2021
#
# Adapted from:
# Return-Address Stack Ordering
# Author: Quinn Pham
# Date: May 7, 2020
#
# Adapted from:
# Reverse Polish Notation Calculator Lab
# Author: Kristen Newbury
# Date: August 9, 2017
#
# RISC-V Modifications
# Author: Abdulrahman Alattas
# Date: May 2, 2019
#
# Adapted from:
# Control Flow Lab - Student Testbed
# Author: Taylor Lloyd
# Date: July 19, 2012
#
# This program reads a file and places it in memory
# and then procedurally jumps to the student code under the label "buildTables", then "buildDictionary", and finally "encode" -
#
#-------------------------------

.data
stackSpace:	.space 	2047
stack:		.byte	0

input:		.space	2048
wordTable:	.space	2048
countTable:	.space	1024
dict:		.space	2048
output:		.space	2048

noFileStr:	.asciz "Couldn't open specified file.\n"
writtenStr:	.asciz " written.\n"

encodingFileName:	.asciz "encoding.txt"
tablesFileName:		.asciz "tables.txt"
createFileStr:	.asciz "Couldn't create specified file.\n"
newLine:	.asciz "\n"
sentinel:	.asciz "\0\0\0\0"

.align 2

.text
main:
	# ---- Prepare stack ----
	addi 	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)


	# ---- read file ----
	lw	a0, 0(a1)	# Put the filename pointer into a0
	li	a1, 0		# Flag: Read Only
	li	a7, 1024	# Service: Open File

	ecall			# File descriptor gets saved in a0 unless an error happens
	bltz	a0, main_err    # Negative means open failed

	la	a1, input	# write into my binary space
	li	a2, 1028        # read a 1kb file (+ size for end-of-file sentinel)
	li	a7, 63          # Read File Syscall
	ecall


	# ---- supply pointers as arguments and call buildTables ----
	la	a0, input
	la 	a1, wordTable
	la	a2, countTable

	jal	buildTables	# call the student subroutine/jump to code under the label 'buildTables' | a0 <- number of elements in either table
	mv s0, a0 		# s0 <- number of elements in either table


	# ---- writing tables to tables.txt ----
	# create tables file and write wordTable
	slli a0, s0, 2		# a0 <- number of bytes in wordTable
	la a1, wordTable
	la a2, tablesFileName
	li a3, 1	# write-create flag
	jal writeFile

	# write sentinel word to separate wordTable and countTable
	li a0, 4		# a0 <- number of bytes in sentinel word
	la a1, sentinel
	la a2, tablesFileName
	li a3, 9	# write-append flag
	jal writeFile

	# write countTable to the tables file
	mv a0, s0
	la a1, countTable
	la a2, tablesFileName
	li a3, 9	# write-append flag
	jal writeFile

	# write sentinel word to signal the end of countTable and the file
	li a0, 4		# a0 <- number of bytes in sentinel word
	la a1, sentinel
	la a2, tablesFileName
	li a3, 9	# write-append flag
	jal writeFile


	# ---- print "tables.txt written." ----
	la a0, tablesFileName # print filename
	li a7, 4
	ecall
	la a0, writtenStr # print " written."
	ecall


	# ---- call buildDictionary ----
	la a0, wordTable
	la a1, countTable
	mv a2, s0
	la a3, dict

	jal	buildDictionary # call the student subroutine/jump to code under the label 'buildDictionary'


	# ---- call encode ----
	mv s0, a0

	la 	a0, input
	la	a1, dict
	mv	a2, s0
	la 	a3, output

	jal	encode 		# call the student subroutine/jump to code under the label 'encode' | a0 <- size of encoded string


	# ---- write encoding.txt ----
	# create encoding file and write encoding to it
	la a1, output
	la a2, encodingFileName
	li a3, 1	# write-create flag
	jal writeFile

	# write end-of-file sentinel word to signal the end of the output file
	li a0, 4		# a0 <- number of bytes in sentinel word
	la a1, sentinel
	la a2, encodingFileName
	li a3, 9	# write-append flag
	jal writeFile


	# ---- print "encoding.txt written." ----
	la a0, encodingFileName # print filename
	li a7, 4
	ecall
	la a0, writtenStr # print " written."
	ecall

	j	main_done


main_err:
	la	a0, noFileStr   # print error message in the event of an error when trying to read a file
	li	a7, 4           # the number of a system call is specified in a7
	ecall             	# Print string whose address is in a0

main_done:
	# Remove stack
	lw	ra, 0(sp)
	lw	s0, 4(sp)
	lw	s1, 8(sp)
	lw	s2, 12(sp)
	addi 	sp, sp, 16

	li      a7, 10          # ecall 10 exits the program with code 0
	ecall


#-------------------------------------------------------------------------------
# writeFile
# adapted from Lab_WASM
#
# opens file and writes bytes to the file
#
# input:
#	a0: number of bytes to be written, value provided by the student
#	a1: address to the beginning of the data to be written to the file
#	a2: address to the beginning of the filename string
#	a3: open flag (1 for write-create, 9 for write-append)
#-------------------------------------------------------------------------------
writeFile:
	# Prepare stack
	addi    sp, sp, -8
	sw      s0, 0(sp)
	sw      s1, 4(sp)

	mv s0, a1
	mv s1, a0
	mv s2, a2

    #open file
	mv      a0, a2         	# filename for writing to
	mv      a1, a3   		# open flag (write-create or write-append)
	li      a7, 1024            # Open File
	ecall
	bltz	a0, writeOpenErr	# Negative means open failed
	mv      t0, a0
    #write to file
	mv      a0, t0
	mv      a1, s0  		# address of buffer from which to start the write from
	mv      a2, s1		# number of bytes to write
	li      a7, 64              # system call for write to file
	ecall                       # write to file
    #close file
	mv      a0, t0              # file descriptor to close
	li      a7, 57              # system call for close file
	ecall                       # close file
	jal     zero, writeFileDone

writeOpenErr:
	la      a0, createFileStr
	li      a7, 4
	ecall

writeFileDone:
	# Remove stack
	lw      s0, 0(sp)
	lw      s1, 4(sp)
	addi    sp, sp, 8
	jalr    zero, ra, 0

printNewLine:
	li 	a7, 11
	li	a0, 10
	ecall

	jr ra

#-------------------end of common file-------------------------------------------------
