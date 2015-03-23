SECTION .data
ALIGN 16
four DQ 4.0, 4.0
two DQ 2.0, 2.0
one DQ 1.0, 1.0
ofs DQ 0.5, 1.5

SECTION .text

extern width,sum,num_rects

global calcPi_SSE
global hasSSE2

; Mit cpuid kann �berpr�ft werden, welche "Features" der Prozessor unterst�tzt.
; Bevor man Instruktionserweiterungen verwendet, sollte hiermit �berpr�ft werden,
; ob diese vorhanden sind.
; Streng genommen muss vorher �berpr�ft werden, ob die Instruktion "cpuid" vorhanden
; ist. Sie existiert erst seit 1993!
hasSSE2:
		push ebp
		mov ebp, esp

		; cpuid �berschreibt eax, ebx, ecx, edx => ebx, ecx sichern
		push ebx
		push ecx

		; Beherrscht der Prozessor SSE2?
		mov eax, 1
		cpuid
		and edx, 5000000h
		cmp edx, 5000000h
		jne not_supported
		mov eax, 1
		jmp done
not_supported:
		mov eax, 0
done:
		mov edx, 0

		pop ecx
		pop ebx

		; ebp restaurieren
		pop ebp
		ret

calcPi_SSE:
		push ebp
		mov ebp, esp
	
		push ebx
		push ecx

		xor ecx, ecx       		; ecx = i = 0
		xorpd xmm0, xmm0   		; xmm0 stellt sum dar
		movsd xmm1, [width]		; initialisiere xmm1 mit width
		shufpd xmm1, xmm1, 0x0
		movapd xmm2, [ofs]		; initialisiere xmm2 mit (0.5, 1.5)

L1:
		cmp ecx, [num_rects]		; Abbruchbedingung �berpr�fen
		jge L2
		; Berechne (i+0.5)*step
		movapd 	xmm4, xmm1
		mulpd 	xmm4, xmm2
		; Quadriere das Zwischenergebniss
		; und erh�he um eins
		mulpd xmm4, xmm4
		addpd xmm4, [one]
		; teile 4 durch das Zwischenergebnis
		movapd	xmm3, [four]
		divpd 	xmm3, xmm4
		; Summiere die ermittelten Rechtecksh�hen auf
		addpd xmm0, xmm3
		; Laufz�hler erh�hen und
		; zum Schleifenanfang springen
		addpd xmm2, [two]
		add ecx, 2
		jmp L1
L2:
		xorpd xmm3,xmm3   ; xmm3 mit 0 initialisieren
		; 1. Element von xmm0 zu xmm3 addieren
		addsd xmm3, xmm0
		; 1. Element von xmm0 durch das 2. ersetzen
		shufpd xmm0, xmm0, 0x1
		; 1. Element von xmm0 zu xmm3 addieren
		addsd xmm3, xmm0
		movsd [sum], xmm3 ; Ergebnis zur�ckkopieren

		pop ecx
		pop ebx

		; ebp restaurieren
		pop ebp
		ret 
