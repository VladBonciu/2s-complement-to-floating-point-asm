.model small
.stack 200h
.data
    a dd ?
    b dd ?
    result dd ?
.code
    ;se stocheaza in ax numarul citit in CC 
    ;poate fi utilizat caracterul '-' pentru introducerea unei valori negative
    ;observatie: CC pe 16 biti poate acoperi valori intre [-32,768, 32,767]
    citireNumarCC PROC
        ;initializam dx cu 10 ca sa facem inmlutirea
        mov dx, 10

        ;golim bx
        xor bx, bx

        ;punem pe stiva val initiala a numarului = 0
        push 0

        ;verificam semnul

            ;citim caracterul
            mov ah, 01h
            int 21h

            ;daca e enter nu mai citeste numar
            cmp al, 13
            je finalNumar

            ;daca caracterul e - schimbam bit ul de semn
            cmp al, 45
            je numarNegativ

            ;daca caracterul nu e -
            jmp numarPozitiv

        numarNegativ:
            mov cx, 1
            jmp citireCifra

        numarPozitiv:
            mov cx, 0
            jmp prelucrareCifra

        citireCifra:
            ;citim caracterul
            mov ah, 01h
            int 21h

            ;daca e enter nu mai citeste numar
            cmp al, 13
            je transformareCDinCC

            prelucrareCifra:

            ;transf numarul citit din ascii in baza 10
            sub al, 30h
            
            ;copiem nr citit in bl
            mov bl, al

            ;punem in ax nr initial
            pop ax

            ;inmultim nr initial cu 10
            mov dx, 10
            mul dx

            ;adaugam nr citit la nr precedent
            add ax, bx

            ;punem pe stiva nr nou
            push ax

            jmp citireCifra
        
        transformareCDinCC:
            ;daca numarul e pozitiv il afisam
            cmp cx, 0
            je finalNumar

            ;daca e negativ il modificam sa fie in CC

            ;scoatem nr de pe stiva
            pop ax

            ;inversam toti bitii din ax (tranf in CI)
            not ax

            ;adaugam 1 (transf in CC)
            inc ax

            ;punem ax pe stiva ca sa il scoata la final
            push ax

            jmp finalNumar

        finalNumar:
            pop ax
            ret

    citireNumarCC ENDP

    ;input : ax - nr intreg (CC) [-32,768, 32,767]
    ;output : cx:dx - (VM SP)
    ;forma: 31->semn ; 30-22->exponent ; 21-0->mantisa
    ;observatie: pentru ca metode de reprezentare CC pe 16 biti poate acoperi valori intre [-32,768, 32,767]
    ;atunci acesta este intervalul de valori care poate fi transformat in VMSP in cadrul acestei proceduri
    transformareCCInVMSP PROC
        ;daca ax e echivalentul a -32768 in CC e caz special de maximum
        cmp ax, 8000h
        je valoareSpecialaMax

        cmp ax, 0000h
        je valoareSpecialaZero

        jmp prelucrareNumar

        valoareSpecialaZero:
            ;valoarea speciala e precalculata si pusa in cx, respectiv dx
            mov cx, 0000h
            mov dx, 0h
            ret

        valoareSpecialaMax:
            ;valoarea speciala e precalculata si pusa in cx, respectiv dx
            mov cx, 0c300h
            mov dx, 0h
            ret
        prelucrareNumar:
            ;prelucrarea initiala a numarului (tranforare in CD fara semn = in baza 2 daca e negativ)
            
            ;punem nr intial pe stiva ca sa prelucram numar pt VMSP mai tarziu
            push ax

            ;copiem ax in dx pt a verifica semnul
            mov dx, ax
            
            ;verificam bit ul de semn si daca e negativ transf in cd fara semn = baza 2
            shr dx, 15

            cmp dx, 1
            je prelucrareNegativ
            jmp prelucrarePozitiv

            prelucrareNegativ:
                ;facem nr in CI
                dec ax

                ;facem nr in CD
                not ax

                ;punem pe stiva nr transf in baza 2
                push ax

                jmp terminarePrelucrareNumar

            prelucrarePozitiv:

                ;punem pe stiva nr transf in baza 2
                push ax

                jmp terminarePrelucrareNumar
        
        terminarePrelucrareNumar:

        ;.BIT-UL DE SEMN

        ;punem nr in baza 2 in bx
        pop ax
        
        ;copie ax
        mov bx, ax

        ;punem nr initial in ax pt prelucrarea semnului
        pop ax

        ; punem iar pe stiva nr in baza 2
        push bx

        ;seteaza bit ul de semn

        ;ia ultimul bit din registru
        shr ax, 15

        shl ax, 15

        ;punem bit - ul de semn in cx
        mov cx, ax

        ;punem nr format pana acum pe stiva
        push cx

        ;.EXPONENT
        
        ;punem din bx (val in baza 2) in ax pt a gasi exponentul
        mov ax, bx

        ;golim cx care o sa fie contorul de putere
        xor cx, cx

        ;cat tip nu s-a gasit valoare 1 dupa trunchierea numarului continua sa trunchiezi si creste puterea
        exoponent:
        
            cmp ax, 1
            je dupaExponent

            shr ax, 1
            inc cx

            jmp exoponent

        dupaExponent:

            ;copiem in dx nr de exponenti
            mov dx, cx

            ;facem exponentul sa resprecte standardul IEEE 754
            add cx, 127

            ;mutam exponentul in pozitia potrivita pt reprezentarea in VMSP
            shl cx, 7

            ;scoatem nr construit pana acum in VMSP (adica doar semnul)
            pop bx

            ;punem in bx numarul creat pana acum in VMSP (semn + exponent)
            add bx, cx

            ;scoate nr in baza 2 in ax
            pop ax
            
            ; punem pe stiva nr creat pana acum
            push bx

        ;.MANTISA

        cmp dx,7
        jg mantisa7SauMaiMult
        jmp mantisa7SauMaiPutin

        mantisa7SauMaiPutin:
        
            ;punem in cx lungimea registrului
            mov cl, 16
            ;din aceasta valorare scadem lunigmea pentru a misca bitii la stanga si a reveni ;
            ;pt a crea in ax partea din mantisa care trebuie sa aparaa in cx dupa exponent
            sub cl, dl

            ;miscam si dam inapoi bitii din ax
            shl ax, cl
            shr ax, cl

            ;punem offsetul necesar in raport cu cat de mare e mantisa
            mov cl, 7
            sub cl, dl

            shl ax, cl

            ;punem in valorarea de pe stiva care reprezinta VMSP cu semn si exponent bitii de pe mantisa
            pop cx
            add cx, ax

            ;mantisa avand mai putin de 7 biti restul valorilor sunt 0
            xor dx,dx

            jmp finalTransformareVMSP

        mantisa7SauMaiMult:

            ;prelucrare primii 7 biti

            ;copiem in bx ax (nr in binar)
            mov bx, ax

            ;punem pe stiva exponentul
            push dx

            ;calculam cati biti trb rotiti pentru a ajunge cu primele 7 pozitii cele care trb sa se afle in ax
            mov cl, dl
            sub cl, 7

            ;rotim biti din ax cu nr de poz calculat (ex: cl = 2 si 0000 0101 -> 0100 0001)
            ror ax, cl

            ;impartim la 128 ca sa gasim restul corespunzator cu cei 7 biti care trb sa fie in cx
            mov cx, 80h
            div cx
            
            ;copiem in ax nr in binar de inainte
            mov ax, bx

            ;copiem in ax restul impartirii
            mov bx, dx

            ;restauram nr de biti din dx
            pop dx

            ; punem biti calculati in prima parte a nr in VMSP
            pop cx
            add cx, bx
            
            ;punem iar pe stiva rezultatul
            push cx

            ;prelucrare restul bitilor

            ; scadem cei 7 biti calculati din lungimea sirului
            sub dx, 7

            ;mutam in cx lungimea maxima dintr un registru
            mov cl, 16
            ;scadem din lungimea maxima cati biti mai trebuie reprezentati
            sub cl, dl
            
            ;mutam bitii din ax la stanga cu nr de pozitii calculate
            ;astfel numarul este reprezentat corect
            shl ax, cl

            ;mutam in dx rezultatul pentru a completa formula cx:dx
            mov dx, ax

            ; scoatem de pe stiva prima parte calculata din nr in VMSP in cx pentru a completa formula cx:dx
            pop cx

            jmp finalTransformareVMSP

        finalTransformareVMSP:
            ret

    transformareCCInVMSP  ENDP

    ;input: ax:bx - deimpartit ; cx:dx = impartitor (ambele in VM SP)
    ;output: cx:dx (VM SP)
    ;.NU FUNCTIONEAZA DECAT BIT-UL DE SEMN SI EXPONENTUL
    ;.DOES NOT WORK
    imparitireVMSP PROC

        ;punem pe stiva valorile pentru mantisa care depasesc primii 7 biti de fractie (vo fi folositi mai tarziu
        push bx
        push dx

        ;punem pe stiva valorile din ax si cx pnetru a le utiliza pentru exponent si mantisa ultierior
        push ax
        push cx

        ;.BIT-UL DE SEMN

        ;mutam toti bitii cu 15 pozitii la dreapta pt a obtine valoarea bit ului de semn in fiecare registru
        shr ax, 15
        shr cx, 15

        ;utilizam functia xor pentru a determina noul semn al rezultatului impartirii
        xor ax, cx

        ;punem bit ul de semn la pozitia potrivita
        shl ax, 15

        ;mutam in dx, noul numar in VMSP
        mov dx, ax

        ;.EXPONENTUL

        ;scoatem valorile de pe stiva pentru a analiza exponentul
        pop cx
        pop ax

        ;repunem valorile pe stiva pentru a le mai analiza o data pentru partea de 7 biti de mantisa
        push ax
        push cx

        ;punem pe stiva numarul creat pana acum
        push dx

        ;extragem valoarea exponentului din numere
        shl ax, 1
        shr ax, 8
        shl cx, 1
        shr cx, 8

        ;scadem din registrii 127 pentru a afla puterea 
        sub ax, 127
        sub cx, 127

        ;scadem exponentul impartitorului din exponentul deimpartitului
        sub ax, cx

        ;mutam diferenta dintre cele doua pentru calcularea exponentului
        mov bx, ax

        ;readaugam 127 pentru a ajunge la standardul IEEE 754
        add ax, 127

        ;mutam bitii de exponent la pozitia lor in reprezentarea VMSP
        shl ax, 7

        ;scoatem numarul format pana acum
        pop dx
        
        ;adaugam bitii de exponent
        add dx, ax

        ;punem pe stiva numarul creat
        push dx

        ;.PARTEA FRACTIONALA
        
        ; ;scoatem primele jumatati ale numarului 
        ; pop cx
        ; pop ax

        ; cmp ax, 0
        ; je
        ; jmp

        pop cx
        pop cx
        pop cx
        pop cx
        
        ret 

    imparitireVMSP ENDP
    
    ;input cx:dx - numar in VMSP
    ;output: afisare cu virgula a numarului in consola in baza 10
    ;observatie: functioneaza doar pentru numere care au pe mantisa maxim 15 biti (din cauza limitarilor de spatiu intr un registru)
    ;astfel aceasta procedura nu afiseaza cu o acuratete precisa partea fractionara
    afisareVMSP PROC

        push dx

        push cx

        ;.SEMN
        
        ;scoatem prima jumatate de pe stiva
        pop ax

        ;si o repunem pe stiva pt mai tarziu
        push cx

        shr ax, 15

        cmp ax, 1
        je afiseazaMinus
        jmp continuareAfisare

        afiseazaMinus:
            mov dl, 45

            mov ah, 02h
            int 21h
        
        continuareAfisare:

        ;cazul de 0

        mov bx, cx
        shl bx, 1
        cmp bx,0
        je afisareZero
        jmp continuareAfisare2

        afisareZero:
            ;daca exponentul si primii 7 biti din mantisa sunt 0 utem afirma ca este 0 reprezentat

            mov dl, '0'
            mov ah, 02h
            int 21h

            mov dl, ','
            mov ah, 02h
            int 21h

            mov dl, '0'
            mov ah, 02h
            int 21h

            pop cx
            pop dx

            ret 

        continuareAfisare2:

       ;.PARTEA INTREAGA

        ;scoatem doar bitii din mantisa ai numarului
        shl cx, 9
        shr cx, 9
        ;adaugam acel 1 al numarului
        add cx, 80h

        ;mutam in ax valoarea primilor 16 biti in VMSP pt a extrage exponentul
        pop ax

        ;il punem iar pe stiva pt ultilizare mai tarziu
        push ax

        ;scoatem doar exponentul din numar
        shl ax, 1
        shr ax, 8
        sub ax, 127

        cmp ax, 7
        jg expMaiMareDe7
        jmp exp7SauMaiMic

        expMaiMareDe7:
            ; copiem in bx nr de biti care sunt in exponent si scadem 7 (cei care se afla in prima jumatate)
            ;pt a vedea cati biti trebuie sa luam din cealalta jumatate
            mov bx, ax
            sub bx, 7
            
            adaugareBitiRamasi:

            cmp bx, 0
            je finalAdaugareBiti

            ;facem loc pentru urmatorul bit
            shl cx, 1

            ;scoatem ultimul bit din a doua jumatate (o sa apara in carry flag)
            shl dx, 1

            ;folosim operatia add with carry (adc) pentru a adauga carry flag ul la numar
            adc cx, 0
            
            ;scadem 1 din nr de biti care trebuie introdusi
            dec bx

            jmp adaugareBitiRamasi
            

            finalAdaugareBiti:

                mov ax, cx

                jmp descompunereParteaIntreaga
            
        exp7SauMaiMic:
            ;copiem nr din prima juamtate in dx 
            mov dx, cx

            ;mutuam in cx 8 (nr bitiilor aflati la inceput in cx)
            mov cx, 8
            ;adaugam bit ul de pe pozitia 8 (cel adaugat pentru a forma numarul)
            inc ax
            ;scadem nr de biti care sunt dupa virgula
            sub cx, ax

            ;scoatem acei biti care nu fac parte din partea intreaga a numarului
            shr dx,cl
            
            ;punem in ax nr care trbeuie descompus
            mov ax, dx
            
            jmp descompunereParteaIntreaga

        descompunereParteaIntreaga:

            mov bx, 10

            mov dx, 0

            mov cx, 0

            push dx

            repetaDescompunereNumar:

            cmp ax, 0
            je afisareParteaIntreaga

            ;impartim la 10 ca sa extragem 
            div bx
            
            ;punem pe stiva restul
            push dx

            inc cx

            ;punem in dx 0 dupa extragerea restului pentru ca ax
            mov dx, 0

            jmp repetaDescompunereNumar

        afisareParteaIntreaga:
            cmp cx, 0
            je finalParteaIntreaga

            pop dx
            add dx, 30h

            dec cx

            mov ah, 02h
            int 21h

            jmp afisareParteaIntreaga

        finalParteaIntreaga:

            ;afisam virgula virgula
            mov dl, 44
            mov ah, 02h
            int 21h

            ;scoatem valorarea reziduala rezultata in urma afisarii
            pop cx

            ; pop bx
            ; pop bx

            ; ret
        
       ;.PARTEA FRACTIONARA
        ;observatie: 0.01 in binar este echivalent cu 0.25 in decimal 
        ;(puterea la care se afla bit ul este puterea la care trebuie inmultit cu 5 si dat offset)

        ;scoatem valoare primei jumatati pentru a extrage exponentul
        pop ax

        ;punem iar valoarea pe stiva pentru a o utiliza mai tarziu
        push ax

        ;scoatem exponentul
        shl ax, 1
        shr ax, 8

        sub ax, 127

        cmp ax, 7
        jg expMaiMareDe7PF
        jmp exp7SauMaiMicPF

        expMaiMareDe7PF:
            ;punem in cx exponentul
            mov cx, ax

            ;scoatem primii 16 biti din numar (nu mai avem nevoie de ei
            pop bx
            ;scoatem a doua jumatate a nr in dx
            pop dx

            ;scoatem n=din numaratoare primii 7 biti din partea intreaga care se regasesc in prima jumatate
            sub cx, 7

            ;punem in bx 0 pt ca mai tarziu sa numaram in acesta bitii care sunt partea fractinara
            xor bx, bx

            ;golim ax pt ca mai tarziu sa fie contorul numarului de biti din partea fractionara
            xor ax, ax

            scoateParteaIntreagaDinADouaJumatate:
                ;daca nu mai sunt biti care sunt din partea intreaga in a doua jumatate atunci 
                ;treci la numararea bitiilor din partea fractionara (parte gasita in exp7SauMaiMicPF)
                cmp cx, 0
                je numaraBitiDinADouaJumatate

                ;scoatem 1 bit din nr
                shl dx,1

                ;scadem nr de biti care reprez partea intreaga
                dec cx

                jmp scoateParteaIntreagaDinADouaJumatate

        exp7SauMaiMicPF:

            ;punem in cx exponentul
            mov cx, ax

            ;punem in bx valoarea primilor 16 biti din VMSP
            pop bx

            ;scoatem bitii care nu apartin partii fractionare din prima jumatate
            shl bx, 9
            shl bx, cl
            shr bx, 9
            shr bx, cl

            ;verificam numarul de biti care au mai ramas din numar 
            mov ax, 7
            sub ax, cx

            ;scaotem a doua parte a nr in VMSP
            pop dx

            numaraBitiDinADouaJumatate:

            ;daca aceasta este 0 atunci nu mai avem informatie de extras
            cmp dx, 0
            je construireParteaFractionara

            ;verificam daca nr de biti este peste 16 (puterea de reprezentare intr un registru)
            cmp ax, 16
            jge construireParteaFractionara

            ;facem loc pt urmatorul bit din partea fractionala
            shl bx, 1

            ;scoatem ultimul bit din dx (care o sa apara in carry)
            shl dx, 1

            ;folosim iar add with carry pentru a pune bit ul in pozitia rezervata
            adc bx, 0

            ;crestem nr bitiilor numarati
            inc ax

            jmp numaraBitiDinADouaJumatate

        construireParteaFractionara:

            ;am ajuns aici cu aceste valori in registrii:
            ;ax - nr de biti din partea fractionara aflati in bx
            ;bx - bitii din partea fractionara (lipiti de partea dreapta)

            ;acum aranjam bitii ca cel mai semnificativ bit al registrului sa fie cel mai semnificativ al PF

            ;punem in cx marimea unui registru
            mov cx, 16
            ;din aceasta valoare scadem cati biti din PF avem
            sub cx, ax

            ;miscam bitii din bx astfel incat cel mai semn. bit din bx sa fie cel mai semn. din PF
            shl bx, cl

            ;copiem nr de bii in dx
            mov dx, ax

            ; punem in ax 1
            mov ax, 1
            
            ;initializam cx cu 0
            xor cx, cx

            ;si il punem pe stiva ca nr initial format
            push cx

            construireNr:
                ;verificam daca au mai ramas biti de analizat care ofera informatie in partea fractionara
                cmp bx, 0
                je descompunereParteaFractionara

                ;mutam bitii la stanga si astfel se schimba carry flag ul cu valoarea bit ului scos
                shl bx, 1

                ;scadem 1 din contorul dx
                dec dx
                
                ; punem in cx 0
                mov cx, 0

                ;adaugam bit ul de carry in cx
                adc cx, 0

                cmp cx, 0
                je  bitulEZero
                jmp bitulEUnu

                bitulEZero:
                    ;inmultim nr cu puteri ale lui 5 chiar daca nu e un bit cu val nenula
                    mov cx,5
                    mul cx
                    jmp construireNr

                bitulEUnu:
                    ;inmultim nr cu puteri ale lui 5 cu 5
                    mov cx,5
                    mul cx

                    ;il copiem in cx
                    mov cx, ax

                    ;scoatem nr format pana acum in ax
                    pop ax

                    ;punem pe stiva nr cu puteri ale lui 5
                    push cx

                    ;punem in cx 10 ca sa marim nr format pana acum
                    mov cx, 10
                    mul cx
                    
                    ;socatem de pe stiva nr cu puteri ale lui 5
                    pop cx
                    
                    ;le adaugam
                    add ax, cx

                    ;punem iar pe stiva nr format pana acum
                    push ax

                    ;punem in ax nr cu puteri ale lui 5
                    mov ax, cx

                    jmp construireNr

        descompunereParteaFractionara:

            ;scoatem valoarea finala a nr format
            pop ax

            ;initializam dx cu 0 pt a face operatii de impartire
            xor dx, dx

            ;initializam cx cu 0 pt a tine cont de cate cifre avem de afisat
            xor cx, cx

            ;initializam impartitorul
            mov bx, 10

            descompunerePF:
                

                ;efectuam impartirea unde in dx va fi restul
                div bx

                ;crestem contorul de cifre
                inc cx

                ;punem restul impartirii pe stiva
                push dx

                ;golim dx ca sa nu intervina cu impartirea
                xor dx, dx

                cmp ax, 0
                je afisarePF
                
                jmp descompunerePF

            afisarePF:

                cmp cx, 0
                je finalParteaFractionara

                pop dx
                add dl, 30h

                mov ah, 02h
                int 21h

                dec cx

                jmp afisarePF
        
        
        finalParteaFractionara: 
            ; pop dx
            ret
    afisareVMSP ENDP

    start:
        mov ax, @data
        mov ds, ax

        ; call citireNumarCC
        
        ; call transformareCCInVMSP

        ; ;punem 21,125 in VMSP la nr care trb afisat
        ; mov cx, 41a9h
        ; mov dx, 0000h

        ; ;punem -27,1875 in VMSP la nr care trb afisat
        ; mov cx, 0C1D9h
        ; mov dx, 8000H

        ; ;punem 527,25 in VMSP la nr care trb afisat
        ; mov cx, 4403h
        ; mov dx, 0d000h

        ; ;punem 27,4183 in VMSP la nr care trb afisat (exemplu de numar care nu este reprezentat corect)
        ; mov cx, 41dbh
        ; mov dx, 58aeh

        ; ;punem 20.617188 in VMSP la nr care trb afisat (nici acesta)
        ; mov cx, 41a4h
        ; mov dx, 0f000h

        call citireNumarCC
        
        call transformareCCInVMSP

        mov     word ptr a + 2, cx    ; Move lower 16 bits of result into AX
        mov     word ptr a , dx ; Move upper 16 bits of result into BX

        call citireNumarCC
        
        call transformareCCInVMSP

        mov     word ptr b + 2, cx    ; Move lower 16 bits of result into AX
        mov     word ptr b , dx ; Move upper 16 bits of result into BX

        FINIT               ; Initialize the coprocessor
        FLD     a      ; Load the first value
        FLD     b      ; Load the second value
        FDIV           ; Perform addition: ST(0) = ST(0) : ST(1)
        FSTP    result      ; Store the result in 'result'
        ; the result should be 0x40bb3333

        mov     cx, word ptr result + 2    ; Move lower 16 bits of result into AX
        mov     dx, word ptr result  ; Move upper 16 bits of result into BX


        call afisareVMSP

        mov ah, 4ch
        int 21h
    end start