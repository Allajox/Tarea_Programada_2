.section .data
prompt_input: .asciz "Ingrese 1 para consola, 2 para archivo: "
prompt_file: .asciz "Ingrese el nombre del archivo: "
prompt_lang: .asciz "¿Fuente en español (s) o malespín (m)? "
output_file: .asciz "convertido.txt"
error_msg: .asciz "Error al abrir archivo\n"
output_msg: .asciz "\nTexto convertido: "
stats_msg:      .asciz "\nEstadísticas:\n==================\n     "
letras_msg:     .asciz "\nTotal de letras ingresadas: "
palabras_msg:   .asciz "\nTotal de palabras ingresadas: "
conv_msg:       .asciz "\nPalabras convertidas: "
mod_msg:        .asciz "\nLetras modificadas: "
porc_msg:       .asciz "\nPorcentaje de modificación: "
porc_sym:       .asciz "%\n==================\n"
num_buffer:     .space 12

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
    bl contar_letras
    bl convertir
    bl imprimir_salida

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
    mov r3, r0
    ldr r1, =buffer
    mov r2, #4096
    mov r7, #3          @ sys_read
    swi #0

    mov r4, r0          @ Guardar longitud del texto leído
    mov r12, #2         @ Marcar modo archivo
    
    bl contar_letras
    bl convertir
    bl imprimir_estadisticas

    mov r0, r3
    mov r7, #6
    swi 0

bucle:
    ldrb r2, [r0], #1
    cmp r2, #10         @ Fin de línea
    beq fin_procesamiento
    cmp r2, #0          @ Fin de texto
    beq fin_procesamiento

    @ Verificar espacios
    cmp r2, #32
    beq espacio

    @ Nueva palabra
    cmp r9, #0
    bne en_palabra
    add r6, r6, #1
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
    @ Verificar modo de salida
    cmp r12, #1
    beq mostrar_consola
    b escribir_archivo

@ ===============================================
@ ===============================================
contar_letras:
    push {lr}
    ldr r0, =buffer
    mov r5, #0          @ Contador de letras
    mov r6, #0          @ Contador de palabras
    mov r9, #0          @ Estado de palabra (1 es palabra convertida, 0 no lo es)

contar_loop:
    ldrb r2, [r0], #1
    cmp r2, #0
    beq fin_conteo

    cmp r2, #' '
    beq es_separador
    cmp r2, #'\n'
    beq es_separador
    cmp r2, #'\t'
    beq es_separador
    
    add r5, r5, #1
    cmp r9, #0
    beq nueva_palabra
    b contar_loop

nueva_palabra:
    add r6, r6, #1      @ Incrementar contador de palabras
    mov r9, #1          @ Marcar palabra
    b contar_loop

es_separador:
    b contar_loop

fin_conteo:
    pop {lr}
    bx lr

convertir:
    ldr r0, =buffer
    ldr r1, =output
    mov r8, #0          @ letras convertidas
    mov r11, #1         @ palabras modificadas

procesar:
    ldrb r2, [r0], #1
    cmp r2, #0
    beq fin_conversion

    cmp r2, #'\n'
    beq es_espacio
    cmp r2, #' '
    beq es_espacio
    cmp r2, #'\''
    beq es_espacio
    b en_palabra

es_espacio:
    b procesar

fin_conversion:
    mov r2, #0
    bx lr

    @ ===============================================
    @ ===============================================

mostrar_consola:
    @ Mostrar mensaje de salida
    mov r0, #1
    ldr r1, =output_msg
    mov r2, #19
    mov r7, #4
    swi 0

    @ Mostrar texto convertido
    mov r0, #1
    ldr r1, =output
    mov r2, r4
    mov r7, #4
    swi 0

escribir_archivo:
    mov r7, #8
    ldr r0, =output_file
    mov r1, #0777
    swi 0

    cmp r0, #-1
    beq error_archivo

    mov r3, r0          @ Guardar descriptor
    ldr r1, =output
    mov r2, r4
    mov r7, #4
    swi 0

    bl imprimir_estadisticas
    b salir

imprimir_salida:
    mov r0, #1
    ldr r1, =output_msg
    mov r2, #19
    mov r7, #4
    swi 0

    mov r0, #1
    ldr r1, =output
    mov r2, #0

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
    
    @ A <-> E
    mov r1, #'A'
    mov r2, #'E'
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ i <-> o
    mov r1, #'i'
    mov r2, #'o'
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ I <-> O
    mov r1, #'I'
    mov r2, #'O'
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ b <-> t
    mov r1, #'b'
    mov r2, #'t'
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ B <-> T
    mov r1, #'B'
    mov r2, #'T'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ f <-> g
    mov r1, #'f'
    mov r2, #'g'
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ F <-> G
    mov r1, #'F'
    mov r2, #'G'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ p <-> m
    mov r1, #'p'
    mov r2, #'m'
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ P <-> M
    mov r1, #'P'
    mov r2, #'M'
    strb r2, [r0, r1]
    strb r1, [r0, r2]
    
    @ Caracteres de ASCII extendido
    @ á (0xA1) <-> é (0xA9)
    mov r1, #0xA1
    mov r2, #0xA9
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ Á (0x81) <-> É (0x89)
    mov r1, #0x81
    mov r2, #0x89
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ í (0xAD) <-> ó (0xB3)
    mov r1, #0xAD
    mov r2, #0xB3
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ Í (0x8D) <-> Ó (0x93)
    mov r1, #0x8D
    mov r2, #0x93
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ ä (0xA4) <-> ë (0xAB)
    mov r1, #0xA4
    mov r2, #0xAB
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ Ä (0x84) <-> Ë (0x8B)
    mov r1, #0x84
    mov r2, #0x8B
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ ï (0xAF) <-> ö (0xB6)
    mov r1, #0xAF
    mov r2, #0xB6
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    @ Ï (0x8F) <-> Ö (0x96)
    mov r1, #0x8F
    mov r2, #0x96
    strb r2, [r0, r1]
    strb r1, [r0, r2]

    bx lr

imprimir_estadisticas:
    push {r4-r7, lr}

    @ Mensaje inicial de estadísticas
    mov r0, #1
    ldr r1, =stats_msg
    mov r2, #34
    mov r7, #4
    swi 0

    @ Total de letras
    mov r0, #1
    ldr r1, =letras_msg
    mov r2, #28
    mov r7, #4
    swi 0
    mov r0, r5
    bl numero_a_ascii

    @ Total de palabras
    mov r0, #1
    ldr r1, =palabras_msg
    mov r2, #30             @ Nueva longitud para "Total de palabras ingresadas: "
    mov r7, #4
    swi 0
    mov r0, r6          @ Total de palabras
    bl numero_a_ascii

    @ Palabras convertidas
    mov r0, #1
    ldr r1, =conv_msg
    mov r2, #22
    mov r7, #4
    swi 0
    mov r0, r11
    bl numero_a_ascii

    @ Letras modificadas
    mov r0, #1
    ldr r1, =mod_msg
    mov r2, #20
    mov r7, #4
    swi 0
    mov r0, r8
    bl numero_a_ascii

    @ Porcentaje
    mov r0, #1
    ldr r1, =porc_msg
    mov r2, #29
    mov r7, #4
    swi 0

    mov r0, #100
    mul r0, r8, r0
    udiv r0, r0, r5
    bl numero_a_ascii

    @ Símbolo de porcentaje y final
    mov r0, #1
    ldr r1, =porc_sym
    mov r2, #22
    mov r7, #4
    swi 0

    pop {r4-r7, lr}
    bx lr

numero_a_ascii:
    push {r4-r7, lr}
    
    ldr r1, =num_buffer
    add r1, r1, #11
    mov r2, #0
    strb r2, [r1]
    mov r2, #10
    mov r4, r1

convert_loop:
    sub r1, r1, #1
    udiv r3, r0, r2
    mul r5, r3, r2
    sub r5, r0, r5
    add r5, r5, #'0'
    strb r5, [r1]
    mov r0, r3
    cmp r0, #0
    bne convert_loop

    mov r0, #1
    mov r2, r4
    sub r2, r2, r1
    mov r7, #4
    swi 0

    pop {r4-r7, lr}
    bx lr

salir:
    mov r7, #1
    swi 0
