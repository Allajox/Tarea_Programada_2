.section .data
prompt_input: .asciz "Ingrese 1 para consola, 2 para archivo: "
prompt_file: .asciz "Ingrese el nombre del archivo: "
prompt_lang: .asciz "¿Fuente en español (s) o malespín (m)? "
output_file: .asciz "convertido.txt"
error_msg: .asciz "Error al abrir archivo\n"
output_msg: .asciz "\nTexto convertido: "
stats_fmt: .asciz "\nEstadísticas:\nTotal palabras: %d\nTotal letras: %d\nPalabras convertidas: %d\nLetras cambiadas: %d\n"

.align 2
translation_table:
.fill 256, 1, 0

.section .bss
.lcomm filename, 256
.lcomm filecontent, 4096
.lcomm buffer, 4096
.lcomm output, 4096
.lcomm total_letras, 4
.lcomm total_palabras, 4
.lcomm conv_palabras, 4
.lcomm conv_letras, 4

.section .text
.global _start

_start:
    bl init_table

    @ Solicitar modo de entrada
    mov r0, #1
    ldr r1, =prompt_input
    mov r2, #41
    mov r7, #4
    swi 0

    @ Leer selección
    mov r0, #0
    ldr r1, =buffer
    mov r2, #2
    mov r7, #3
    swi 0

    ldrb r0, [r1]
    cmp r0, #'1'
    beq leer_consola
    cmp r0, #'2'
    beq leer_archivo
    b salir

leer_consola:
    @ Limpiar buffer
    mov r0, #0
    ldr r1, =buffer
    mov r2, #4096
    mov r7, #3
    swi 0
    mov r4, r0          @ Guardar longitud del texto
    mov r12, #1         @ Marcar modo consola
    b procesar

leer_archivo:
    @ Pedir nombre del archivo
    mov r0, #1
    ldr r1, =prompt_file
    mov r2, #31
    mov r7, #4
    swi 0

    mov r0, #0          @ stdin
    ldr r1, =filename
    mov r2, #256
    mov r7, #3          @ sys_read
    swi #0

    @ Procesar nombre del archivo
    cmp r0, #0
    ble error_archivo
    sub r0, r0, #1
    ldr r1, =filename
    mov r2, #0
    strb r2, [r1, r0]

    @ Abrir archivo
    ldr r0, =filename
    mov r1, #0          @ 0_RDONLY
    mov r7, #5          @ sys_open
    swi #0

    cmp r0, #-1
    beq error_archivo


    @ Leer contenido del archivo
    mov r5, r0
    ldr r1, =buffer
    mov r2, #4096
    mov r7, #3          @ sys_read
    swi #0

    mov r4, r0          @ Guardar longitud del texto leído
    mov r12, #2         @ Marcar modo archivo
    
    mov r0, r5
    mov r7, #6
    swi 0
    
    b procesar

procesar:
    mov r5, #0          @ total_letras
    mov r6, #0          @ total_palabras
    mov r8, #0          @ conv_letras
    mov r9, #0          @ en_palabra
    mov r10, #0         @ palabra_modificada
    mov r11, #0         @ conv_palabras

    ldr r0, =buffer
    ldr r1, =output

bucle:
    ldrb r2, [r0], #1
    cmp r2, #10         @ Fin de línea
    beq fin_procesamiento
    cmp r2, #0          @ Fin de texto
    beq fin_procesamiento

    @ Contar letras
    add r5, #1

    @ Verificar espacios
    cmp r2, #32
    beq espacio

    @ Nueva palabra
    cmp r9, #0
    bne en_palabra
    add r6, #1
    mov r9, #1
    mov r10, #0

en_palabra:
    @ Traducir caracter
    ldr r3, =translation_table
    ldrb r3, [r3, r2]
    cmp r3, #0
    moveq r3, r2        @ Si no hay traducción, mantener original
    strb r3, [r1], #1

    @ Contar cambios
    cmp r3, r2
    beq sin_cambio
    add r8, #1
    mov r10, #1

sin_cambio:
    b bucle

espacio:
    strb r2, [r1], #1
    cmp r9, #0
    beq bucle
    mov r9, #0
    cmp r10, #0
    beq bucle
    add r11, #1
    b bucle

fin_procesamiento:
    @ Guardar estadísticas
    ldr r0, =total_letras
    str r5, [r0]
    ldr r0, =total_palabras
    str r6, [r0]
    ldr r0, =conv_palabras
    str r11, [r0]
    ldr r0, =conv_letras
    str r8, [r0]

    @ Verificar modo de salida
    cmp r12, #1
    beq mostrar_consola
    b escribir_archivo

mostrar_consola:
    @ Mostrar mensaje de salida
    mov r0, #1
    ldr r1, =output_msg
    mov r2, #17
    mov r7, #4
    swi 0

    @ Mostrar texto convertido
    mov r0, #1
    ldr r1, =output
    mov r2, r4
    mov r7, #4
    swi 0

    bl imprimir_estadisticas
    b salir

escribir_archivo:
    mov r7, #8
    ldr r0, =output_file
    mov r1, #0777
    swi 0

    cmp r0, #-1
    beq error_archivo

    mov r5, r0          @ Guardar descriptor
    ldr r1, =output
    mov r2, r4
    mov r7, #4
    swi 0

    bl imprimir_estadisticas
    b salir

error_archivo:
    mov r0, #1
    ldr r1, =error_msg
    mov r2, #23
    mov r7, #4
    swi 0
    b salir

init_table:
    @ Inicializar tabla traducción
    ldr r0, =translation_table
    mov r1, #0
1:  
    strb r1, [r0, r1]
    add r1, #1
    cmp r1, #256
    blt 1b

    @ Mapeos malespín
    ldr r0, =translation_table
    
    @ a <-> e
    mov r1, #'a'
    mov r2, #'e'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ i <-> o
    mov r1, #'i'
    mov r2, #'o'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ b <-> t
    mov r1, #'b'
    mov r2, #'t'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ f <-> g
    mov r1, #'f'
    mov r2, #'g'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ p <-> q
    mov r1, #'p'
    mov r2, #'m'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    bx lr

imprimir_estadisticas:
    mov r0, #1
    ldr r1, =stats_fmt
    mov r2, #100
    mov r7, #4
    swi 0
    bx lr

salir:
    mov r7, #1
    swi 0
