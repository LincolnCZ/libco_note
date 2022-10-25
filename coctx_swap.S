/*
* Tencent is pleased to support the open source community by making Libco available.

* Copyright (C) 2014 THL A29 Limited, a Tencent company. All rights reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License"); 
* you may not use this file except in compliance with the License. 
* You may obtain a copy of the License at
*
*	http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, 
* software distributed under the License is distributed on an "AS IS" BASIS, 
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
* See the License for the specific language governing permissions and 
* limitations under the License.
*/

.globl coctx_swap
#if !defined( __APPLE__ ) && !defined( __FreeBSD__ )
.type  coctx_swap, @function
#endif
coctx_swap:

// coctx_swap(coctx_t curr,coctx_t pending)

#if defined(__i386__)
   
	leal 4(%esp), %eax //sp 
	movl 4(%esp), %esp 
	leal 32(%esp), %esp //parm a : &regs[7] + sizeof(void*)

	pushl %eax //esp ->parm a 

	pushl %ebp
	pushl %esi
	pushl %edi
	pushl %edx
	pushl %ecx
	pushl %ebx
	pushl -4(%eax)

	
	movl 4(%eax), %esp //parm b -> &regs[0]

	popl %eax  //ret func addr
	popl %ebx  
	popl %ecx
	popl %edx
	popl %edi
	popl %esi
	popl %ebp
	popl %esp
	pushl %eax //set ret func addr

	xorl %eax, %eax
	ret

#elif defined(__x86_64__)
    // 以下代码将协程 A，切换到协程B运行
    //（1）将之前 cpu 寄存器的值保存到了协程 A 的 regs[14] 中
	leaq 8(%rsp),%rax   // 父函数栈帧中除返回地址外栈帧顶的位置
	
	// rdi 寄存器存的是第一个参数的地址，其 112 个字节后，是 regs 数组后的位置。
	// 难道是要把 ss_size 的首地址放进去？
	// 显然不是的，因为栈的地址从高位到低位
    // 所以，再度 push 的时候，将会首先填充 regs[13] ，一直填充到 reg[0]
	// 设置栈顶指针为
	leaq 112(%rdi),%rsp 
	
	// 将寄存器保存到入栈,因为此时栈的地址指向数组，因此实际上就是将各个寄存器填充到数组中
	pushq %rax  // rax -> regs[13]，也就是当前的rsp -> regs[13]
	pushq %rbx  // rbx -> regs[12]
	pushq %rcx  // rcx -> regs[11]
	pushq %rdx  // rdx -> regs[10]

    
	pushq -8(%rax) // ret func addr  返回地址 -> regs[9]

	pushq %rsi  // rsi -> regs[8]
	pushq %rdi  // rdi -> regs[7]
	pushq %rbp  // rbp -> regs[6]
	pushq %r8   // r8 -> regs[5]
	pushq %r9   // r9 -> regs[4]
	pushq %r12   // r12 -> regs[3]
	pushq %r13    // r13 -> regs[2]
	pushq %r14   // r14 -> regs[1]
	pushq %r15   // r15 -> regs[0]  // r15 是程序计数器
	
	// 截止到此，所有的协程上下文保存成功 

    //（2）将协程 B regs[14] 的内容写入到了寄存器中
	// rsi 中是第二个参数，我们需要将第二个参数的上下文载入到寄存器和栈里面
	// rsi 的首地址就是整个 regs[] 参数的地址，从 0 开始，所以当 pop 的时候，将从 0 将参数 pop 出来。
    // 这里用的方法还是通过改变 %rsp 的值，把某块内存当作栈来使用。第一句 movq %rsi, %rsp 就是让 %rsp 指向 coctx_swap 第二个参数，这一参数
    //   表示要进入的协程。而第二个参数也是 coctx_t 类型的指针，即执行完 movq 语句后，%rsp 指向了第二个参数 coctx_t 中 regs[0]，而之后的 pop
    //   语句就是用 regs[0-13] 中的值填充 cpu 的寄存器，这里需要注意的是 popq 会使得 %rsp 的值增加而不是减少，这一点保证了会从 regs[0] 到
    //   regs[13] 依次弹出到 cpu 寄存器中。在执行完最后一句 popq %rsp 后，%rsp 已经指向了新协程要恢复的栈指针（即新协程之前调用 coctx_swap
    //   时父函数的栈帧顶指针），由于每个协程都有一个自己的栈空间，可以认为这一语句使得 %rsp 指向了要进入协程的栈空间。
	movq %rsi, %rsp

    // 以下为倒序还原
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %r9
	popq %r8
	popq %rbp
	popq %rdi
	popq %rsi
	popq %rax //ret func addr
	popq %rdx
	popq %rcx
	popq %rbx
	popq %rsp

    //（3）利用了 ret 语句来实现修改指令寄存器 %rip 的目的，通过修改 %rip 来实现程序运行逻辑跳转
	pushq %rax // 将返回地址入栈
	// 将 eax 寄存器清零，eax 是 rax 的低 32 位，也就是将 rax 的低 32 位清零。也就是 return 0 的意思。
	xorl %eax, %eax
	// 返回函数
	ret
#endif
