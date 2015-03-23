SECTION .data
ALIGN 32
four DQ 4.0, 4.0, 4.0, 4.0
two DQ 2.0, 2.0, 2.0, 2.0
one DQ 1.0, 1.0, 1.0, 1.0
ofs DQ 0.5, 1.5, 2.5, 3.5

SECTION .text

extern width,sum,num_rects

global calcPi_AVX
global hasAVX

; Mit cpuid kann �berpr�ft werden, welche "Features" der Prozessor unterst�tzt.
; Bevor man Instruktionserweiterungen verwendet, sollte hiermit �berpr�ft werden,
; ob diese vorhanden sind.
; Streng genommen muss vorher �berpr�ft werden, ob die Instruktion "cpuid" vorhanden
; ist. Sie existiert erst seit 1993!
hasAVX:
		push ebp
		mov ebp, esp

		; cpuid �berschreibt eax, ebx, ecx, edx => ebx, ecx sichern
		push ebx
		push ecx

		; Beherrscht der Prozessor beherrscht AVX?
		; Verwendet das OS XASVE und XRSTOR?
		mov eax, 1
		cpuid
		and ecx, 18000000h ; pr�fe bit 27 (OS uses XSAVE/XRSTOR)
		cmp ecx, 18000000h ; und 28 (AVX supported by CPU)
		jne not_supported

		; Unterst�tzt das OS AVX?
		xor ecx, ecx
		xgetbv
		and eax, 110b
		cmp eax, 110b ; Werden die AVX-Registern bei einem Kontextwechsel gesichert?
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

calcPi_AVX:
		push ebp
		mov ebp, esp
	
		push ebx
		push ecx

		xor ecx, ecx       		; ecx = i = 0
		vxorpd ymm0, ymm0, ymm0   	; ymm0 stellt sum dar
		vbroadcastsd ymm1, [width] 	; initialisiere ymm1 mit step
		vmovapd ymm2, [ofs]		; initialisiere ymm2 mit (0.5, 1.5, 2.5, 3.5)
		vmovapd ymm3, [four] 		; initialisiere ymm3 mit (4.0, 4.0, 4.0, 4.0)

L1:
		cmp ecx, [num_rects]		; Abbruchbedingung �berpr�fen
		jge L2
		; Berechne (i+0.5)*step
		vmulpd 	ymm4, ymm1, ymm2
		; Quadriere das Zwischenergebniss
		; und erh�he um eins
		vmulpd ymm4, ymm4, ymm4
		vaddpd ymm4, ymm4, [one]
%if 0
		; teile 4 durch das Zwischenergebnis
		vdivpd 	ymm4, ymm3, ymm4
%else
		; vdivpd ist extrem langsam
		; Idee: Approximiere den Reziprokwert und
		; verfeinere die Liesung mit mit den Newton-Raphson Verfahren
		vmovapd ymm5, ymm4
		vmovapd ymm6, ymm4
		vcvtpd2ps xmm4, ymm5            ; Konvertiere in einfache Genauigkeit
		vrcpps    xmm4, xmm4		; Approximiere den Reziprokwert (Genauigkeit 2^-12)
		vcvtps2pd ymm4, xmm4		; Konvertiere nun wieder zur�ck
		; Newton-Raphson Verfahren anwenden, um eine genaueres Ergebnis zu haben
		; x1 = x0 * (2 - d * x0) = 2 * x0 - d * x0 * x0;
		vmulpd   ymm5, ymm4
		vmulpd   ymm5, ymm4
		vaddpd   ymm4, ymm4
		vsubpd   ymm4, ymm5
		; Die Genauigkeit ist nun 2^-23
		; => noch eine Iteration, um eine doppelte Genauigkeit (nach IEEE) 
		; zu erzielen.
		vmulpd   ymm6, ymm4
		vmulpd   ymm6, ymm4
		vaddpd   ymm4, ymm4
		vsubpd   ymm4, ymm6
		; mit 4 multiplizieren
		vmulpd   ymm4, ymm3
%endif 
		; Summiere die ermittelten Rechtecksh�hen auf
		vaddpd ymm0, ymm0, ymm4
		; Laufz�hler erh�hen und
		; zum Schleifenanfang springen
		vaddpd ymm2, ymm2, ymm3
		add ecx, 4
		jmp L1
L2:
		vperm2f128 ymm3, ymm0, ymm0, 0x1 ; tausche die niedrigen mit den h�heren 128 Bits
		vaddpd ymm3, ymm3, ymm0  ; implizit werden die oberen mit den niedrigen 128 Bits addiert
		vhaddpd ymm3, ymm3, ymm3 ; die unteren beiden Zahlen addiert
		vmovsd [sum], xmm3 ; Ergebnis zur�ckkopieren

		pop ecx
		pop ebx

		; ebp restaurieren
		pop ebp
		ret 
