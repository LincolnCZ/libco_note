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


#ifndef __CO_ROUTINE_INNER_H__

#include "co_routine.h"
#include "coctx.h"
struct stCoRoutineEnv_t;
struct stCoSpec_t
{
	void *value;
};

/**
* 协程栈：一个共享栈的，这里就是共享栈的内存所在了；每个协程也可以使用独立栈
* 一个进程或者线程栈的地址，是从高位到低位安排数据的，所以 stack_bp 是栈底，stack_buffer 是栈顶
*/
struct stStackMem_t
{
	stCoRoutine_t* occupy_co; // 当前正在使用该共享栈的协程
	int stack_size;   // 栈的大小
	char* stack_bp;   // stack_buffer + stack_size 栈底
	char* stack_buffer; // 栈的内容，也就是栈顶
};

/*
* 共享栈，这里的共享栈是个数组，每个元素分别是个共享栈
*/
struct stShareStack_t
{
	unsigned int alloc_idx; // 应该是目前正在使用的那个共享栈的 index
	int stack_size; // 共享栈的大小，这里的大小指的是一个 stStackMem_t* 的大小
	int count;   // 共享栈的个数，共享栈可以为多个，所以以下为共享栈的数组
	stStackMem_t** stack_array; //栈的内容，这里是个数组，元素是 stStackMem_t*
};

//协程
struct stCoRoutine_t
{
    /*不同于 Go 语言，libco 的协程一旦创建之后便跟创建时的那个线程绑定了的，是不支持在不同线程间迁移（migrate）的。这个 env，即同属于一个线程
     * 所有协程的执行环境，包括了当前运行协程、上次切换挂起的协程、嵌套调用的协程栈，和一个 epoll 的封装结构（TBD）。*/
	stCoRoutineEnv_t *env;  // 协程所在的运行环境，可以理解为，该协程所属的协程管理器
	
	pfn_co_routine_t pfn; // 协程所对应的函数
	void *arg; // 函数参数
	coctx_t ctx; // 协程上下文，包括寄存器和栈

	// 以下用 char 表示了 bool 语义，节省空间
	char cStart;          // 是否已经开始运行了
	char cEnd;            // 是否已经结束
	char cIsMain;         // 是否是主协程
	char cEnableSysHook;  // 是否要打开钩子标识，默认是关闭的
	char cIsShareStack;   // 是否要采用共享栈

	void *pvEnv;

	//char sRunStack[ 1024 * 128 ];
	stStackMem_t* stack_mem; // 该协程可以用的栈内存，固定大小


	//save satck buffer while conflict on same stack_buffer;
	char* stack_sp; // rsp，栈顶
	unsigned int save_size; // save_buffer 的长度
	char* save_buffer; // 当协程挂起时，栈的内容会栈暂存到 save_buffer 中

	stCoSpec_t aSpec[1024]; 
};



//1.env
void 				co_init_curr_thread_env();
stCoRoutineEnv_t *	co_get_curr_thread_env();

//2.coroutine
void    co_free( stCoRoutine_t * co );
void    co_yield_env(  stCoRoutineEnv_t *env );

//3.func



//-----------------------------------------------------------------------------------------------

struct stTimeout_t;
struct stTimeoutItem_t ;

stTimeout_t *AllocTimeout( int iSize );
void 	FreeTimeout( stTimeout_t *apTimeout );
int  	AddTimeout( stTimeout_t *apTimeout,stTimeoutItem_t *apItem ,uint64_t allNow );

struct stCoEpoll_t;
stCoEpoll_t * AllocEpoll();
void 		FreeEpoll( stCoEpoll_t *ctx );

stCoRoutine_t *		GetCurrThreadCo();
void 				SetEpoll( stCoRoutineEnv_t *env,stCoEpoll_t *ev );

typedef void (*pfnCoRoutineFunc_t)();

#endif

#define __CO_ROUTINE_INNER_H__
