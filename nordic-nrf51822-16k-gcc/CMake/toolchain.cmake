# Copyright (C) 2014-2015 ARM Limited. All rights reserved.

if(TARGET_NORDIC_NRF51822_16K_GCC_TOOLCHAIN_INCLUDED)
    return()
endif()
set(TARGET_NORDIC_NRF51822_16K_GCC_TOOLCHAIN_INCLUDED 1)

# legacy definitions for building mbed 2.0 modules with a retrofitted build
# system:
set(MBED_LEGACY_TARGET_DEFINITIONS "NORDIC" "NRF51822_MKIT" "MCU_NRF51822" "MCU_NORDIC_16K")
# provide compatibility definitions for compiling with this target: these are
# definitions that legacy code assumes will be defined. 
add_definitions("-DNRF51 -DTARGET_NORDIC -DTARGET_M0 -D__MBED__=1 -DMCU_NORDIC_16K -DTARGET_NRF51822 -DTARGET_MCU_NORDIC_16K")

# append non-generic flags, and set NRF51822-specific link script
set(_CPU_COMPILATION_OPTIONS "-mcpu=cortex-m0 -mthumb -D__thumb2__")

set(CMAKE_C_FLAGS_INIT             "${CMAKE_C_FLAGS_INIT} ${_CPU_COMPILATION_OPTIONS}")
set(CMAKE_ASM_FLAGS_INIT           "${CMAKE_ASM_FLAGS_INIT} ${_CPU_COMPILATION_OPTIONS}")
set(CMAKE_CXX_FLAGS_INIT           "${CMAKE_CXX_FLAGS_INIT} ${_CPU_COMPILATION_OPTIONS}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${CMAKE_MODULE_LINKER_FLAGS_INIT} -mcpu=cortex-m0 -mthumb")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${CMAKE_EXE_LINKER_FLAGS_INIT} -mcpu=cortex-m0 -mthumb -T${CMAKE_CURRENT_LIST_DIR}/../ld/NRF51822.ld")

# used by the apply_target_rules function below:
set(NRF51822_SOFTDEVICE_HEX_FILE "${CMAKE_CURRENT_LIST_DIR}/../softdevice/s130_nrf51_1.0.0_softdevice.hex")

# define a function for yotta to apply target-specific rules to build products,
# in our case we need to convert the built elf file to .hex, and add the
# pre-built softdevice:

# first find the post-processing programs that we need
find_program(ARM_NONE_EABI_OBJCOPY arm-none-eabi-objcopy)
find_program(SREC_CAT_PROGRAM srec_cat)

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

if(NOT ARM_NONE_EABI_OBJCOPY)
    # gcc_program_notfound is defined by the mbed-gcc target
    gcc_program_notfound("arm-none-eabi-objcopy")
endif()

# now define the actual post-processing steps
function(yotta_apply_target_rules target_type target_name)
    if(${target_type} STREQUAL "EXECUTABLE")
        add_custom_command(TARGET ${target_name}
            POST_BUILD
            # objcopy to hex
            COMMAND ${ARM_NONE_EABI_OBJCOPY} -O ihex ${target_name} ${target_name}.hex
            # and append the softdevice hex file
            COMMAND ${SREC_CAT_PROGRAM} ${NRF51822_SOFTDEVICE_HEX_FILE} -intel ${target_name}.hex -intel -o ${target_name}-combined.hex -intel --line-length=44
            COMMENT "hexifying and adding softdevice to ${target_name}"
            VERBATIM
        )
    endif()
endfunction()
