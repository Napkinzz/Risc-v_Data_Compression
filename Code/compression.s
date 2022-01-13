.include "common.s"
#---------------------------------------------------------------------------------------------
# buildTables
#
# Arguments:
#	a0: the address of the contents of a valid input file in memory terminated by the end-of-file sentinel word.
#	a1: the address of pre-allocated memory in which to store the wordTable.
#	a2: the address of pre-allocated memory in which to store the countTable.
#
# Return Values:
#	a0: the number of words in the wordTable (is equivalent to the number of counts in the countTable)
#
# Generates a wordTable alongside a correlated countTable
#---------------------------------------------------------------------------------------------
# saves all s-regs used and move arguments into s regs 
buildTables:		
	addi sp,sp,-12				# store s regs we are using 
	sw s2, 0(sp)
	sw s3, 4(sp)
	sw s10, 8(sp)
	sw s11, 12(sp)
						# save arguments in s reg 
	mv s10, a1				# s10 <--- Word Array 
	mv s11, a2				# s11 <--- Count Array
	li s2, 0				# s2 <--- counter 
	li s3, 0 				# s3 <--- array total 

# loads a input word in t0 (stopping when the sentinal is found) 	
#---------------------------------------------------------------------------------------------
start:	
	lw t0, 0(a0)				# loads a word into t0
	beqz t0, exit_buildTables		# when the null string is hit exit 
	li s2, 0				# set counter back to 0			
	mv a1,s10				# copy s10 back into a1 reg 

# looks in the dictionary to see if the word is already added, if it is it will branch to count_add and increment the index
# when the counter is the same as the # of words in the dictionary it will branch to add_word	
#---------------------------------------------------------------------------------------------
loop:	
	beq s2, s3, add_word			# if counter == the amount in array we know we must add the new word 
	lw t1, 0(a1)				# loads the current word in word array 
	beq t0,t1,count_add			# go to count_add if to(input word)==t1(word in word array)
	addi a1,a1,4				# increment word array 
	addi s2,s2,1				# increment counter 
	j loop					# jump to loop 
			
# this is called when we need to increment the counter for a specific word (that is already in the dictionary) by 1	
#---------------------------------------------------------------------------------------------
count_add: 
     	add s11,s11,s2				# move the count array to the correct index ()counter)
	lbu t3, 0(s11)				# loads the current byte 
	addi t3,t3, 1				# increments that byte by one 
	sb t3, 0(s11)				# save it back after incrementing 
	addi a0,a0,4				# increment the input to get the next word 
	sub s11,s11,s2				# return the count array 
	j start					# jump to start label

# this is called when the input word matchs nothing currently in the dictionary, will add the new word to the end of the 
# word array and incremment the count array accordingly	
#---------------------------------------------------------------------------------------------	
add_word:    
	slli t5,s2,2				# t5 <--- index * 4 	
	add s10,s10,t5				# WordArray[count*4]     go to correct index in a1 
	sw t0, 0(s10)				# save in word array
	li t6, 1				# make number 1 
	add s11,s11, s3				# countArray[count]      go to correct index in count array 
	sb t6, 0(s11)				# store 1 in the count array 
	sub s10,s10,t5				# return the WordArray 
	sub s11,s11,s3				# return the count array 
	addi s3,s3,1				# increment number in the array 
	addi a0,a0,4				# increment the input to get the next word 
	j start					# jump to start label
	
# when the sentinal word is hit will load the array total (s3) into a0 to return it. Restores all regs and stack.
# Jumps to caller. 
#---------------------------------------------------------------------------------------------
exit_buildTables:
	mv a0,s3				# return the number of words in the word table 
	lw s2, 0(sp)				# restore s regs 
	lw s3, 4(sp)
	lw s10, 8(sp)
	lw s11, 12(sp)
	addi sp,sp,12
	jr ra 

#---------------------------------------------------------------------------------------------
# encode
#
# Arguments:
#	a0: the address to the contents of a valid input file in memory.
#	a1: the address of a dictionary table in memory.
#	a2: the number of words in the dictionary.
#	a3: the address of pre-allocated memory in which to store the output.
#
# Return Values:
#	a0: the size of the output in bytes (not including the end-of-file sentinel word at the end).
#
# Compresses the contents of an input file
#---------------------------------------------------------------------------------------------
# saves all regs used and stores arguments in s regs 
#---------------------------------------------------------------------------------------------
encode:
	addi sp,sp,-28			# store everything 
	sw s0, 0(sp)
	sw s1, 4(sp)
	sw s2, 8(sp)
	sw s3, 12(sp)
	sw s4, 16(sp)
	sw ra, 20(sp)			
	sw s11, 24(sp)
	sw s10, 28(sp)
	
	li s10, 0			# counter 
	mv s0, a0			# s0 <--- the address to the contents of a valid input file in memory.
	mv s1, a1			# s1 <--- the address of a dictionary table in memory.
	mv s2, a2			# s2 <--- the number of words in the dictionary.
	mv s3, a3 			# s3 <--- the address of pre-allocated memory in which to store the output.
	li s11, 0			# byte counter 

# adds the dictionary portion of the encoding to the front of the output. 
#---------------------------------------------------------------------------------------------
add_dict:
	lw t4, 0(s1)			# t4 <-- word in dict 
	beq s10,s2, add_null		# if counter == # of words in dictionary branch to add_input 
	sw t4, 0(s3)			# move dict to output 
	addi s11,s11,4			# increase the total count by four bytes 
	addi s10,s10,1			# increment counter 
	addi s3,s3,4			# increment output 
	addi s1,s1,4			# increment dictionary 
	j add_dict			# jump back to the top 

# after add_dict is done will add a null byte to the end of the dictionary entry 
#---------------------------------------------------------------------------------------------
add_null:
	slli s10, s10, 2			# counter *4 to reset dict 
	sub s1,s1,t0			# reset dict back to starting address 
	li t1, 0x00			# load null character byte 
	sb t1, 0(s3)			# write the byte 
	addi s11,s11,1			# increase the total count by 1 byte 
	addi s3,s3,1			# move over the byte 
	
# gets the input word. Checks if the function needs to exit, will call locate word to see if it is in the dictionary
# returns to the ra and resets the dictionary memory location and increments to the next word.
#---------------------------------------------------------------------------------------------
input_word:
	lw s4, 0(s0)			# s4 <--- valid word from input 
	beqz s4, exit_encode 		# when nnull character is hit exit 
	li s10, 0			# t0 <--- reset counter  
	j locate_word 			# see if its in dictionary 
reset:	
	slli s10,s10,2			# t0 * 4 
	sub s1,s1,s10			# set dict back to base 
	addi s0,s0,4			# increment input 
	j input_word			# jump back to top for the next word 
	
# will scan the dictionary to see if there is a match between the 2 words, and if there is it will call add_index if not it will 
# call add_manually and append the word to the output 
#---------------------------------------------------------------------------------------------
locate_word:				# s4 <--- input word 
					# t1 <--- word in dict 
	lw t1, 0(s1)			# t1 <--- word in dictionary 
	beq t1,s4, add_index		# if word in dict == word from input
	beq s10, s2, add_manually 	# if the word isnt found i.e count == max len of dict 
	addi s1,s1,4			# increment dict 
	addi s10,s10,1			# increment count 
	j locate_word			# jump to top  

# this is called if there is a match from the input word and the dictionary. Will change bit 7 of the index location to 1 
# and then append the reference to a word in the dictionary to the end of the output. 
#---------------------------------------------------------------------------------------------
add_index: 				# t0 <--- index position 
	mv a0, s10			# move count into argument reg
	jal flip_byte 			# flip the byte 
	sb a0, 0(s3)			# store the flipped byte in the output 
	addi s11,s11,1			# add one to the size counter 
	addi s3,s3,1			# increment output 
	j reset				# jump to reset 
	
# this is called when the word is not found in the dictionary. This is append the entire 4 byte word (as seperate bytes not lw) 
# to the end of the output 
#---------------------------------------------------------------------------------------------
add_manually:
	lbu t3, 0(s0)			# load the word into bytes 
	lbu t4, 1(s0)			# load the word into bytes 	
	lbu t5, 2(s0)			# load the word into bytes 	
	lbu t6, 3(s0)			# load the word into bytes 
	sb t3, 0(s3)			# store the bytes 
	sb t4, 1(s3)			# store the bytes 
	sb t5, 2(s3)			# store the bytes 	
	sb t6, 3(s3)			# store the bytes 
	addi s3,s3,4			# increment output 
	addi s11,s11,4			# add four bytes to the size counter  
	j reset				# jump to reset
	
# this is called when the sentinal word from the input is hit. i.e 0000 0000 Loads all the saved regs and resets stack. 
# moves s11(size counter) to the return address and jumps back to caller.
#---------------------------------------------------------------------------------------------
exit_encode:					
	li t1, 0x00			# add sentinal byte by byte
	sb t1, 0(s3)			# add sentinal byte by byte	
	sb t1, 1(s3)			# add sentinal byte by byte
	sb t1, 2(s3)			# add sentinal byte by byte
	sb t1, 3(s3)			# add sentinal byte by byte
	mv a0,s11			# return the size counter 
	
	lw s0, 0(sp)			# restore s regs 
	lw s1, 4(sp)
	lw s2, 8(sp)
	lw s3, 12(sp)
	lw s4, 16(sp)
	lw ra, 20(sp)
	lw s11, 24(sp)
	lw s10, 28(sp)
	addi sp,sp,28
	jr ra
	

flip_byte:
#---------------------------------------------------------------------------------------------
# flip_byte 
#
# Arguments:
#	a0: input byte to add a 1 in pos 7 to use as a flag
#
# Return Values:
#	a0: the input byte, putting a 1 in pos 7
#
# Takes a input byte and puts a 1 in pos 7 i.e Input: 0000 0000   ---> Output: 1000 0000
#---------------------------------------------------------------------------------------------
	li t1, 1			# t1 <--- 1 
	slli t1,t1,7			# t1 <--- 1000 0000
	xor a0, a0,t1			# flips byte 7 (we know there cannot be a 1 in pos 7 before this)
	jr ra				# jumps back to add_index 
#------------------     end of student solution     ----------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------
# buildDictionary
#
# Arguments:
#	a0: pointer to a wordTable in memory.
#	a1: pointer to a corresponding countTable in memory.
#	a2: the number of elements in either table.
#	a3: pointer to pre-allocated memory in which to store dictionary table.
#
# Return Values:
#	a0: the number of word elements in the dictionary.
#
# Generates a dictionary table.
#-------------------------------------------------------------------------------------------------------------------------------
buildDictionary: # provided to students
	addi sp, sp, -32
	sw ra, 0(sp)	# storing registers
	sw s0, 4(sp) 
	sw s1, 8(sp)
	sw s2, 12(sp)
	sw s3, 16(sp)
	sw s4, 20(sp)
	sw s5, 24(sp)
	sw s6, 28(sp)


	mv s0, a0	# s0 <- address to wordTable
	mv s1, a1	# s1 <- address to countTable
	mv s2, a2	# s2 <- number of elements in wordTable or countTable
	li s3, 0	# s3 <- tableIndex
	mv s4, a3	# s4 <- dictPos
	li s5, 2	# s5 <- threshold
	mv s6, a3	# s6 <- dictStart
	
	tableIteration:
		bge s3, s2, endOfTable	# if reached the end of the tables
		add t0, s1, s3	# t0 <- address of count in countTable at index tableIndex
		lbu t1, 0(t0)	# t1 <- count
		bge t1, s5, addToDict	# if a count is >= threshold, add the corresponding word to the dictionary
		
		addi s3, s3, 1	# updating tableIndex
		
		j tableIteration
		
		addToDict:
			slli t0, s3, 2	# t0 <- s3 * 4 = word offset corresponding to tableIndex
			add t0, s0, t0	# t0 <- address of word in wordTable at index tableIndex
			lw t1, 0(t0)	# t1 <- word
			
			addi s3, s3, 1	# updating tableIndex

			sw t1, 0(s4)	# store the word in the dictionary
			addi s4, s4, 4	# update dictPos
			
			j tableIteration
		
	endOfTable:
		
		sub t0, s4, s6	# t0 <- size of dictionary
		srli a0, t0, 2	# a1 <- t0 / 4 = number of words in dictionary
		
		lw ra, 0(sp)	# restoring registers
		lw s0, 4(sp) 
		lw s1, 8(sp)
		lw s2, 12(sp)
		lw s3, 16(sp)
		lw s4, 20(sp)
		lw s5, 24(sp)
		lw s6, 28(sp)
		addi sp, sp, 32
		
		ret
