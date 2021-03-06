// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.
// See the LICENSE file in the project root for more information.

.intel_syntax noprefix
#include "unixasmmacros.inc"
#include "asmconstants.h"


//////////////////////////////////////////////////////////////////////////
//
// PrecodeFixupThunk
//
// The call in fixup precode initally points to this function.
// The pupose of this function is to load the MethodDesc and forward the call the prestub.
//
// EXTERN_C VOID __stdcall PrecodeFixupThunk()
LEAF_ENTRY PrecodeFixupThunk, _TEXT

        pop     rax         // Pop the return address. It points right after the call instruction in the precode.

        // Inline computation done by FixupPrecode::GetMethodDesc()
        movzx   r10,byte ptr [rax+2]    // m_PrecodeChunkIndex
        movzx   r11,byte ptr [rax+1]    // m_MethodDescChunkIndex
        mov     rax,qword ptr [rax+r10*8+3]
        lea     METHODDESC_REGISTER,[rax+r11*8]

        // Tail call to prestub
        jmp C_FUNC(ThePreStub)

LEAF_END PrecodeFixupThunk, _TEXT

// EXTERN_C int __fastcall HelperMethodFrameRestoreState(
//         INDEBUG_COMMA(HelperMethodFrame *pFrame)
//         MachState *pState
//         )
LEAF_ENTRY HelperMethodFrameRestoreState, _TEXT

#ifdef _DEBUG
        mov     rdi, rsi
#endif

        // Check if the MachState is valid
        xor     eax, eax
        cmp     qword ptr [rdi + OFFSETOF__MachState___pRetAddr], rax
        jne      DoRestore
        REPRET
DoRestore:

        //
        // If a preserved register were pushed onto the stack between
        // the managed caller and the H_M_F, m_pReg will point to its
        // location on the stack and it would have been updated on the
        // stack by the GC already and it will be popped back into the
        // appropriate register when the appropriate epilog is run.
        // 
        // Otherwise, the register is preserved across all the code
        // in this HCALL or FCALL, so we need to update those registers
        // here because the GC will have updated our copies in the 
        // frame.
        //
        // So, if m_pReg points into the MachState, we need to update
        // the register here.  That's what this macro does.
        //
#define RestoreReg(reg, regnum) \
        lea     rax, [rdi + OFFSETOF__MachState__m_Capture + 8 * regnum]; \
        mov     rdx, [rdi + OFFSETOF__MachState__m_Ptrs + 8 * regnum]; \
        cmp     rax, rdx; \
        cmove   reg, [rax];

        // regnum has to match ENUM_CALLEE_SAVED_REGISTERS macro
        RestoreReg(R12, 0)
        RestoreReg(R13, 1)
        RestoreReg(R14, 2)
        RestoreReg(R15, 3)
        RestoreReg(Rbx, 4)
        RestoreReg(Rbp, 5)

        xor     eax, eax
        ret

LEAF_END HelperMethodFrameRestoreState, _TEXT

//////////////////////////////////////////////////////////////////////////
//
// NDirectImportThunk
//
// In addition to being called by the EE, this function can be called
//  directly from code generated by JIT64 for CRT optimized direct
//  P/Invoke calls. If it is modified, the JIT64 compiler's code
//  generation will need to altered accordingly.
//
// EXTERN_C VOID __stdcall NDirectImportThunk()//
NESTED_ENTRY NDirectImportThunk, _TEXT, NoHandler

        //
        // Save integer parameter registers.
        // Make sure to preserve r11 as well as it is used to pass the stack argument size from JIT
        //
        PUSH_ARGUMENT_REGISTERS
        push_register r11
        
        //
        // Allocate space for XMM parameter registers
        //
        alloc_stack     0x80 

        SAVE_FLOAT_ARGUMENT_REGISTERS 0

    END_PROLOGUE

        //
        // Call NDirectImportWorker w/ the NDirectMethodDesc*
        //
        mov             rdi, METHODDESC_REGISTER
        call            C_FUNC(NDirectImportWorker)
        
        RESTORE_FLOAT_ARGUMENT_REGISTERS 0

        //
        // epilogue, rax contains the native target address
        //
        free_stack      0x80

        //
        // Restore integer parameter registers and r11
        //
        pop_register r11
        POP_ARGUMENT_REGISTERS
        
    TAILJMP_RAX
NESTED_END NDirectImportThunk, _TEXT

// EXTERN_C void moveOWord(LPVOID* src, LPVOID* target);
// <NOTE>
// MOVDQA is not an atomic operation.  You need to call this function in a crst.
// </NOTE>
LEAF_ENTRY moveOWord, _TEXT
        movdqu          xmm0, xmmword ptr [rdi]
        movdqu          xmmword ptr [rsi], xmm0

        ret
LEAF_END moveOWord, _TEXT

//------------------------------------------------
// JIT_RareDisableHelper
//
// The JIT expects this helper to preserve registers used for return values
//
NESTED_ENTRY JIT_RareDisableHelper, _TEXT, NoHandler

    // First integer return register
    push_register rax
    // Second integer return register
    push_register rdx
    alloc_stack         0x28
    END_PROLOGUE
    // First float return register
    movdqa              xmmword ptr [rsp], xmm0
    // Second float return register
    movdqa              xmmword ptr [rsp+0x10], xmm1

    call                C_FUNC(JIT_RareDisableHelperWorker)

    movdqa              xmm0, xmmword ptr [rsp]
    movdqa              xmm1, xmmword ptr [rsp+0x10]
    free_stack          0x28
    pop_register        rdx
    pop_register        rax
    ret

NESTED_END JIT_RareDisableHelper, _TEXT

#ifdef FEATURE_HIJACK

//------------------------------------------------
// OnHijackScalarTripThread
//
NESTED_ENTRY OnHijackScalarTripThread, _TEXT, NoHandler

    // Make room for the real return address (rip)
    push_register rax

    PUSH_CALLEE_SAVED_REGISTERS

    push_register rdx
    // Push rax again - this is where integer/pointer return values are returned
    push_register rax

    mov                 rdi, rsp

    alloc_stack         0x28

    // First float return register
    movdqa              [rsp], xmm0
    // Second float return register
    movdqa              [rsp+0x10], xmm1

    END_PROLOGUE

    call                C_FUNC(OnHijackScalarWorker)

    movdqa              xmm0, [rsp]
    movdqa              xmm1, [rsp+0x10]
    free_stack          0x28
    pop_register        rax
    pop_register        rdx

    POP_CALLEE_SAVED_REGISTERS
    ret

NESTED_END OnHijackScalarTripThread, _TEXT

#ifdef FEATURE_UNIX_AMD64_STRUCT_PASSING
//------------------------------------------------
// OnHijackStructInRegsTripThread
//
NESTED_ENTRY OnHijackStructInRegsTripThread, _TEXT, NoHandler

    // Make room for the real return address (rip)
    push_register rax

    PUSH_CALLEE_SAVED_REGISTERS

    push_register rdx
    // Push rax again - this is where part of the struct gets returned
    push_register rax

    mov                 rdi, rsp

    alloc_stack         0x28

    // First float return register
    movdqa              [rsp], xmm0
    // Second float return register
    movdqa              [rsp+0x10], xmm1

    END_PROLOGUE

    call                C_FUNC(OnHijackStructInRegsWorker)

    movdqa              xmm0, [rsp]
    movdqa              xmm1, [rsp+0x10]
    free_stack          0x28
    pop_register        rax
    pop_register        rdx

    POP_CALLEE_SAVED_REGISTERS
    ret

NESTED_END OnHijackStructInRegsTripThread, _TEXT
#endif // FEATURE_UNIX_AMD64_STRUCT_PASSING

//------------------------------------------------
// OnHijackObjectTripThread
//
NESTED_ENTRY OnHijackObjectTripThread, _TEXT, NoHandler 

    // Make room for the real return address (rip)
    push_register rax

    PUSH_CALLEE_SAVED_REGISTERS

    push_register rdx
    // Push rax again - this is where integer/pointer return values are returned
    push_register rax

    mov                 rdi, rsp

    // align stack
    alloc_stack         0x8

    END_PROLOGUE

    call                C_FUNC(OnHijackObjectWorker)

    free_stack          0x8
    pop_register        rax
    pop_register        rdx

    POP_CALLEE_SAVED_REGISTERS
    ret

NESTED_END OnHijackObjectTripThread, _TEXT

//------------------------------------------------
// OnHijackInteriorPointerTripThread
//
NESTED_ENTRY OnHijackInteriorPointerTripThread, _TEXT, NoHandler 

    // Make room for the real return address (rip)
    push_register rax

    PUSH_CALLEE_SAVED_REGISTERS

    push_register rdx
    // Push rax again - this is where integer/pointer return values are returned
    push_register rax

    mov                 rdi, rsp

    // align stack
    alloc_stack         0x8

    END_PROLOGUE

    call                C_FUNC(OnHijackInteriorPointerWorker)

    free_stack          0x8
    pop_register        rax
    pop_register        rdx

    POP_CALLEE_SAVED_REGISTERS
    ret

NESTED_END OnHijackInteriorPointerTripThread, _TEXT

#endif // FEATURE_HIJACK

LEAF_ENTRY SinglecastDelegateInvokeStub, _TEXT                                        
                                                                                      
        test    rdi, rdi                                                              
        jz      NullObject                                                            
                                                                                      
                                                                                      
        mov     rax, [rdi + OFFSETOF__DelegateObject___methodPtr]                     
        mov     rdi, [rdi + OFFSETOF__DelegateObject___target]  // replace "this" pointer
                                                                                      
        jmp     rax                                                                   
                                                                                      
NullObject:                                                                           
        mov     rdi, CORINFO_NullReferenceException_ASM                               
        jmp     C_FUNC(JIT_InternalThrow)
                                                                                      
LEAF_END SinglecastDelegateInvokeStub, _TEXT
