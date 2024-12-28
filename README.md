#  2️⃣s ->☁️. Two's Complement to Floating Point Converter in _ASM_

A small coding project I made to enhance my coding skills in assembly on the _**16-bit Intel 80286** processor._

My goal with this project was to be able to _**read a number in Two's Complement**_, then _**convert it into a Floating Point format**_ and after that be able to _**display it on the screen in base 10**_.

The limitations that I set for myself were to **not use the coprocessor unit (maths coprocessor), as well as any variables** inside of the data segment, goals which were achieved.

## How can I run this?

The way I coded and tested this script was through the [MASM/TASM](https://marketplace.visualstudio.com/items?itemName=xsro.masm-tasm) plugin inside of Visual Studio Code.

After installing the plugin you can right click on the code snippet that you wish to run and select the **‘Run ASM code’** option.

## How did I make this?

There are _3 working procedures_ at the moment iside of the .asm file:

### 1) Reading values from the keyboard and converting them in Two's Complement

The program is reading characters from the keyboard until Enter (CR in ASCII) is met. (including a - at the begining if needed)

_Note that we can only represent numbers in the range of **[-32,768, 32,767]** using 16 bits._

**_Example:_**

_Input:_ **-2354**

_Output:_ **AX : F6CEh**

### 2) Transforming the Two's complement number into a Floating Point format

By running this procedure you make the 16-bit number in 2s Complement found in the AX register into a Floating Point format that is stored in CX:DX.

**_Example:_**

_Input:_ **AX: 68E5h** (26853 in 2s Complement)

_Output:_ 
**CX : 46D9h**
**DX : 9A00h** (The same number in Floating point format)

### 3) Output of a number represented in the Floating Point format

This is one of the most finnicky parts of the program, as the small number of bits inside of a register limits the amount of precision that is needed to represent a floating point number, thus resulting in a less than desirable accuracy of the fractional part of the number.

**_Example 1:_**

_Input:_ **CX : C1D9h** **DX : 8000h** (-27,1875 in Floating Point format)

_Output:_ -27,1875

**_Example 2:_**

_Input:_ **CX : 41A4h** **DX : F000h** (20.617188 in Floating Point format)

_Output:_ 20,42227 (Accuracy of representation was lost)

## License

This project is under the [MIT License](https://github.com/VladBonciu/2s-complement-to-floating-point-asm?tab=MIT-1-ov-file), so have fun with it!
