# Copyright (C) 2014-2015 ARM Limited. All rights reserved.

if(TARGET_NORDIC_NRF51822_16K_ARMCC_TOOLCHAIN_INCLUDED)
    return()
endif()
set(TARGET_NORDIC_NRF51822_16K_ARMCC_TOOLCHAIN_INCLUDED 1)

# legacy definitions for building mbed 2.0 modules with a retrofitted build
# system:
set(MBED_LEGACY_TARGET_DEFINITIONS "NORDIC" "NRF51822_MKIT" "MCU_NRF51822" "MCU_NORDIC_16K")
# provide compatibility definitions for compiling with this target: these are
# definitions that legacy code assumes will be defined.
add_definitions("-DNRF51 -DTARGET_NORDIC -DTARGET_M0 -D__MBED__=1 -DMCU_NORDIC_16K -DTARGET_NRF51822 -DTARGET_MCU_NORDIC_16K -D__CORTEX_M0 -DARM_MATH_CM0")

# append non-generic flags, and set NRF51822-specific link script
set(_CPU_COMPILATION_OPTIONS "--CPU=Cortex-M0 -D__thumb2__")

set(CMAKE_C_FLAGS_INIT             "${CMAKE_C_FLAGS_INIT} ${_CPU_COMPILATION_OPTIONS}")
set(CMAKE_ASM_FLAGS_INIT           "${CMAKE_ASM_FLAGS_INIT} ${_CPU_COMPILATION_OPTIONS}")
set(CMAKE_CXX_FLAGS_INIT           "${CMAKE_CXX_FLAGS_INIT} ${_CPU_COMPILATION_OPTIONS}")
#set(CMAKE_MODULE_LINKER_FLAGS_INIT "${CMAKE_MODULE_LINKER_FLAGS_INIT}")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${CMAKE_EXE_LINKER_FLAGS_INIT} --info=totals --list=.link_totals.txt --scatter ${CMAKE_CURRENT_LIST_DIR}/../ld/nRF51822.sct")

# used by the apply_target_rules function below:
set(NRF51822_SOFTDEVICE_HEX_FILE "${CMAKE_CURRENT_LIST_DIR}/../softdevice/s130_nrf51_1.0.0_softdevice.hex")

# define a function for yotta to apply target-specific rules to build products,
# in our case we need to convert the built elf file to .hex, and add the
# pre-built softdevice:

# first find the post-processing programs that we need
find_program(ARM_NONE_EABI_SIZE arm-none-eabi-size)
find_program(ARMCC_FROMELF_PROGRAM fromelf)
find_program(SREC_CAT_PROGRAM srec_cat)
find_program(SREC_INFO_PROGRAM srec_info)

macro(srec_program_notfound progname)
    message("**************************************************************************\n")
    message(" ERROR: the s-record program ${progname} could not be found\n")
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows" OR CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
        message(" you can install the s-record tools from:")
        message(" https://!!!FIXME ")
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        message(" it is included in the srecords package that you can install")
        message(" with homebrew:\n")
        message("   brew install srecord")
    endif()
    message("\n**************************************************************************")
    message(FATAL_ERROR "missing program prevents build")
    return()
endmacro()

if(NOT SREC_CAT_PROGRAM)
    srec_program_notfound("srec_cat")
endif()

if(NOT SREC_INFO_PROGRAM)
    srec_program_notfound("srec_info")
endif()

if(NOT ARMCC_FROMELF_PROGRAM)
    # arm_toolchain_program_notfound is defined by the mbed-armcc target
    arm_toolchain_program_notfound("fromelf")
endif()

# now define the actual post-processing steps
function(yotta_apply_target_rules target_type target_name)
    if(${target_type} STREQUAL "EXECUTABLE")
        add_custom_command(TARGET ${target_name}
            POST_BUILD
            # fromelf to hex
            COMMAND ${ARMCC_FROMELF_PROGRAM} --i32combined --output=${target_name}.hex ${target_name}
            # and append the softdevice hex file
            COMMAND ${SREC_CAT_PROGRAM} ${NRF51822_SOFTDEVICE_HEX_FILE} -intel ${target_name}.hex -intel -o ${target_name}-combined.hex -intel --line-length=44
            COMMAND ${SREC_INFO_PROGRAM} ${target_name}-combined.hex -intel
            COMMENT "hexifying and adding softdevice to ${target_name}"
            VERBATIM
        )
        # it's quite likely that people won't have the binutils tool used for
        # displaying size info installed, so only display that info if they do
        if(${ARM_NONE_EABI_SIZE})
            add_custom_command(TARGET ${target_name}
                POST_BUILD
                COMMAND ${ARM_NONE_EABI_SIZE} ${target_name}
                COMMENT "displaying size info for ${target_name}"
                VERBATIM
            )
        endif()
    endif()
endfunction()
