#import "isoiec.typ": isoiec, syntax, note, example, index, para_continue, stable_tag

#show: doc => isoiec(
	title: "Programming Languages — C — defer, a mechanism for general purpose, lexical scope-based undo",
	authors: ("JeanHeyd Meneide (wg14@soasis.org)"),
	keywords: ("C", "defer", "ISO/IEC 9899", "Technical Specification", "Safety", "Resource"),
	id: "NXYZ0",
	ts_id: "25755",
	stage: "cd",
	abstract: [The advent of resource leaks in programs created with ISO/IEC 9899#index[ISO/IEC 9899] ⸺ Programming Languages, C has necessitated the need for better ways of tracking and automatically releasing resources in a given scope. This document provides a feature to address this need in a reliable, translation-time, opt-in manner for implementations to furnish to programmers.],
	doc
)

= Scope #stable_tag("scope") <scope>

This Technical Specification specifies a series of extensions of the programming language C, specified by the international standard ISO/IEC 9899:2024#index[ISO/IEC 9899:2024].

Each clause in this Technical Specification deals with a specific topic. The first sub-clauses of clauses 4 through 7 contain a technical description of the features of the topic and what is necessary for an implementation to achieve conformance through extensions or additions to ISO/IEC 9899:2024#index[ISO/IEC 9899:2024].



= Normative References #stable_tag("normrefs") <normrefs>

The following documents are referred to in the text in such a way that some or all of their content constitutes requirements of this document. For dated references, only the edition cited applies. For undated references, the latest edition of the referenced document (including any amendments) applies.

#list(marker: [],
	indent: 1.5em,
	[ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], Programming languages — C]
)



= Terms and definitions #stable_tag("defn") <defn>

For the purposes of this document, the terms and definitions of ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] apply.



= Conformance #stable_tag("conf") <conf>

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 4 apply without any additional requirements in this document.



= Environment #stable_tag("env") <env>

== General #stable_tag("env-general") <env-general>

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 5 apply along with the following additional requirements to support the ```c defer```#index(apply-casing: false, display: [```c defer```], "Keywords", "defer") feature.

== Program termination #stable_tag("prog.term") <prog.term>

=== Semantics

If the return type of the ```c main``` function#index(apply-casing: false, display: [```c main``` function], "main") is a type compatible with ```c int```, a ```c return``` from the initial call to the main function is equivalent to calling the ```c exit``` function with the value returned by the ```c main``` function as its argument after all defer statements#index[defer statement] that are in scope for the ```c main``` function have been executed.
#index("program termination")




= Language #stable_tag("lang") <lang>

== General #stable_tag("lang-general") <lang-general>

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 6 apply along with the following additional requirements to support the ```c defer```#index(apply-casing: false, display: [```c `defer```], "Keywords", "defer") feature.

== Keywords #stable_tag("keywords") <keywords>

In addition to the keywords in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §6.4.2, an implementation shall additionally recognize ```c defer```#index(apply-casing: false, display: [```c defer```], "Keywords", "defer") as a keyword.

=== Recommended practice

An additional -- or, possibly, replacement -- keyword ```c _Defer```#index(apply-casing: false, display: [```c _Defer```], "Keywords", "_Defer") should be provided as an alternative spelling for the ```c defer``` keyword#index(apply-casing: false, display: [```c defer```], "Keywords", "defer"), in conjunction with the recommended practice in @lib-stddefer.hdr. It should have all the significance of the ```c defer``` keyword described in this document. This can aid in portability.

== Statements #stable_tag("statements") <statements>

In addition to the statements in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §6.8, implementations shall allow the unlabeled statement grammar production to produce a defer statement#index[defer statement] which contains a deferred block#index[deferred block]. A deferred block#index[deferred block] is also considered a _block_ just like a primary block or a secondary block.

=== Syntax

#par[
	#syntax([_unlabeled-statement_:],
		list(marker: none, indent: 8em,
			[_expression-statement_],
			[_attribute-specifier-sequence_#sub[opt] _primary-block_],
			[_attribute-specifier-sequence_#sub[opt] _jump-statement_],
			[_attribute-specifier-sequence_#sub[opt] _defer-statement_]
		)
	)

	#syntax([_deferred-block_:],
		list(marker: none, indent: 8em,
			[_unlabeled-statement_]
		)
	)
]
#index("unlabeled statement")
#index("defer statement")

== Defer statements #stable_tag("defer") <defer>

=== Syntax

#par[
	#syntax([_defer-statement_:],
		list(marker: none, indent: 8em,
			[`defer` _deferred-block_]
		)
	)
]
#index("defer statement")
#index(apply-casing: false, display: [```c defer```], "Keywords", "defer")

=== Description

Let _D_ be a defer statement#index[defer statement], _S_ be the deferred block#index[deferred block] of _D_, and _E_ be the enclosing block of _D_. The scope of _D_ is the same as an identifier declared and completed immediately after the end of _S_.

=== Constraints

Jumps by means of:

- ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]) or ```c switch```#index("Keywords", "switch", apply-casing: false, display:[```c switch```]) shall not jump into any defer statement;#index[defer statement]
- ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]) or ```c switch```#index("Keywords", "switch", apply-casing: false, display:[```c switch```]) shall not jump from outside the scope of a defer statement#index[defer statement] _D_ to inside that scope;
- and, ```c return```#index("Keywords", "return", apply-casing: false, display:[```c return```]), ```c break```#index("Keywords", "break", apply-casing: false, display:[```c break```]), ```c continue```#index("Keywords", "continue", apply-casing: false, display:[```c continue```]) or ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]) shall not exit _S_.

=== Semantics

When execution reaches a defer statement#index[defer statement] _D_ and its scope is entered, its _S_ is not immediately executed during sequential execution of the program. Instead, for the duration of the scope of _D_, _S_ is executed upon:

- the termination of the block _E_ and/or the scope of _D_ (such as from reaching its end);
- or, any exit from _E_ and/or the scope of _D_ through ```c return```#index("Keywords", "return", apply-casing: false, display:[```c return```]), ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]), ```c break```#index("Keywords", "break", apply-casing: false, display:[```c break```]), or ```c continue```#index("Keywords", "continue", apply-casing: false, display:[```c continue```]).

#para_continue() The execution is done just before leaving the enclosing block _E_ and/or the scope of _D_. In particular ```c return``` expressions (and conversion to return values)#index("conversions") are calculated before executing _S_.

Multiple defer statements#index[defer statement] execute their _S_ in the reverse order they appeared in _E_. Within a single defer statement#index[defer statement] _D_, if _D_ contains one or more defer statements#index[defer statement] _D#sub[sub]_ of its own, then the _S#sub[sub]_ of the _D#sub[sub]_ are also executed in reverse order at the termination and/or exit of _E#sub[sub]_ and/or _D#sub[sub]_'s scope, recursively, according to the rules of this subclause.

If a non-local jump #index("non-local jump") is used in _D_'s scope but before the execution of the _S_ of _D_:

- if execution leaves _D_'s scope, _S_ is not executed;
- otherwise, if control returns to a point in _E_ and causes _D_ to be reached more than once, the effect is the same as reaching _D_ only once.

#note() The "execution" of a defer statement#index[defer statement] only enures that _S_ is run on any exit from that scope. There is no observable side effect to repeat from reaching _D_, as the manifestation of any of the effects of _S_ happen if and only if the scope of _D_ is exited or terminated after reaching _D_, as previously specified. "Tracking" of reached defer statements at execution time is not necessary: if the non-local jump leaves the scope it is not executed (forgotten); and, if its reached again it behaves as it would during normal execution.


If a non-local jump #index("non-local jump") is executed from _S_ and control leaves _S_, the behavior is undefined#index("undefined behavior").

If a non-local jump #index("non-local jump") is executed outside of any _D_ and:

- it jumps into any _S_;
- or, it jumps outside any _D_'s scope to inside that _D_'s scope;

#para_continue() the behavior is undefined#index("undefined behavior").

If _E_ has any defer statements#index[defer statement] _D_ that have been reached and their _S_ have not yet executed, but the program is terminated or leaves the scope of _D_ through any means not specified previously, including but not limited to:

- a function with the `_Noreturn` function specifier, or a function annotated with the `noreturn` or `_Noreturn` attribute, is called;#index(initial: "n", display: [`_Noreturn`], apply-casing: false, "_Noreturn")#index(apply-casing: false, display: [`noreturn`], "noreturn")
- or, any signal `SIGABRT`, `SIGINT`, or `SIGTERM` occurs;#index("signal")

then any such _S_ are not run, unless otherwise specified by the implementation. Any other _D_ that have not been reached do not have their _S_ run.

#note() The execution of deferred statements upon non-local jumps (i.e., `longjmp` and `setjmp` described in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §7.13)#index("non-local jump") or program termination is a technique sometimes known as "unwinding" or "stack unwinding", and some implementations perform it. See also ISO/IEC 14882#index[ISO/IEC 14882] Programming languages — C++ *[except.ctor]*.

#example() Defer statements#index[Defer statement] cannot be jumped over.#index("Keywords", "goto", apply-casing: false, display:[```c goto```])

```c
#include <stdio.h>

int f() {
	goto target; // constraint violation
	defer { fputs(" meow", stdout); }
target:
	fputs("cat says", stdout);
	return 1;
}

int g() {
	// print "cat says" to standard output
	return fputs("cat says", stdout);
	defer { fputs(" meow", stdout); } // okay: no constraint violation,
	// not executed
}

int h() {
	goto target;
	{
		// okay: no constraint violation
		defer { fputs(" meow", stdout); }
	}
target:
	fputs("cat says", stdout);
	return 1; // prints "cat says" to standard output
}

int i() {
	{
		defer { fputs("cat says", stdout); }
		// okay: no constraint violation
		goto target;
	}
target:
	fputs(" meow", stdout);
	return 1; // prints "cat says meow" to standard output
}

int j() {
	defer {
		goto target; // constraint violation
		fputs(" meow", stdout);
	}
target:
	fputs("cat says", stdout);
	return 1;
}

int k() {
	defer {
		return 5; // constraint violation
		fputs(" meow", stdout);
	}
	fputs("cat says", stdout);
	return 1;
}

int l() {
	defer {
target:
		fputs(" meow", stdout);
	}
	goto target; // constraint violation
	fputs("cat says", stdout);
	return 1;
}

int m() {
	goto target; // okay: no constraint violation
	{
target:
		defer { fputs("cat says", stdout); }
	}
	fputs(" meow", stdout);
	return 1; // prints "cat says meow" to standard output
}

int n() {
	goto target; // constraint violation
	{
		defer { fputs(" meow", stdout); }
target:
	}
	fputs("cat says", stdout);
	return 1;
}

int o() {
	{
		defer fputs("cat says", stdout);
		goto target;
	}
target:;
	fputs(" meow", stdout);
	return 1; // prints "cat says meow"
}

int p() {
	{
		goto target;
		defer fputs(" meow", stdout);
	}
target:;
	fputs("cat says", stdout);
	return 1; // prints "cat says"
}

int q() {
	{
		defer { fputs(" meow", stdout); }
target:
	}
	goto target; // constraint violation
	fputs("cat says", stdout);
	return 1;
}

int r() {
	{
target:
		defer { fputs("cat says", stdout); }
	}
	goto target; // ok
	fputs(" meow\n", stdout);
	return 1; // prints "cat says" repeatedly
}

int s() {
	{
target:
		defer { fputs("cat says", stdout); }
		goto target; // ok
	}
	// never reached
	fputs(" meow", stdout);
	return 1; // prints "cat says" repeatedly
}

int t() {
	int count = 0;
	{
target:
		defer { fputs("cat says ", stdout); }
		++count;
		if (count <= 2) {
			goto target; // ok
		}
	}
	fputs("meow", stdout);
	return 1; // prints "cat says cat says cat says meow"
}

int u() {
	int count = 0;
	{
		defer { fputs("cat says", stdout); }
	target:
		if (count < 5) {
			++count;
			goto target; // ok
		}
	}
	fputs(" meow", stdout);
	return 1; // prints "cat says meow"
}

int v() {
	int count = 0;
target: if (count >= 2) {
		fputs("meow", stdout);
		return 1; // prints "cat says cat says meow "
	}
	defer { fputs("cat says ", stdout); }
	count++;
	goto target;
	return 0; // never reached
}
```

#example() All the expressions and statements of an enclosing block are evaluated before executing defer statements#index[defer statement], including any conversions#index[conversions]. After all defer statements#index[defer statement] are executed, the block is then exited.

```c
int main() {
	int r = 4;
	int* p = &r;
	defer { *p = 5; }
	return *p; // return 4;
}
```

#para_continue() This is important for proper resource management in conjunction with potentially complex return expressions.

```c
#include <stdlib.h>
#include <stddef.h>

int f(size_t n, void* buf) {
	/* ... */
	return 0;
}

int main() {
	const int size = 20;
	void* buf = malloc(size);
	defer { free(buf); }
	// buffer is not freed until AFTER use_buffer returns
	return use_buffer(size, buf);
}
```

#para_continue() Conversions#index("conversions") for the purposes of return are also computed before ```c defer```#index(apply-casing: false, display: [```c defer```], "Keywords", "defer") is entered.

```c
#include <float.h>
#include <assert.h>

bool f() {
	double x = DBL_SNAN;
	defer {
		// fetestexcept(FE_INVALID) is nonzero because of the
		// comparison during the conversion to bool
		assert(fetestexcept(FE_INVALID) != 0);
	}
	return x;
}
```

#example() It is not defined if defer statements#index[defer statement] execute their deferred blocks if the exiting / non-returning functions detailed previously#index("program termination") are called.

```c
#include <stdlib.h>

int f() {
	void* p = malloc(1);
	if (p == NULL) {
		return 0;
	}
	defer free(p);
	exit(1); // "p" may be leaked
	return 1;
}

int main() {
	return f();
}
```

#example() Defer statements#index[Defer statement], when execution reaches them, are tied to the scope of the defer statement within their enclosing block, even if it is a secondary block without braces.

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
	{
		defer {
			fputs(" meow", stdout);
		}
		if (true)
			defer fputs("cat", stdout);
		fputs(" says", stdout);
	}
	// "cat says meow" is printed to standard output
	exit(0);
}
```

This applies to any enclosing block, even ```c for``` loops without braces around its body.

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
	const char* arr[] = {"cat", "kitty", "ferocious little baby"};
	defer {
		fputs(" meow", stdout);
	}
	for (unsigned int i = 0; i < 3; ++i)
		defer printf("my %s,\n", arr[i]);
	fputs("says", stdout);
	
	// "my cat,
	// my kitty,
	// my ferocious little baby,
	// says meow"
	// is printed to standard output
	return 0;
}
```

#example() Defer statements#index[Defer statement] execute their deferred blocks#index[deferred block] in reverse order of the appearance of the defer statements, and nested defer statements#index[defer statement] execute their deferred blocks#index[deferred block] in reverse order but at the end of the deferred block#index[deferred block] they were invoked within. The following program:

```c
int main() {
	int r = 0;
	{
		defer {
			defer r *= 4;
			r *= 2;
			defer {
				r += 3;
			}
		}
		defer r += 1;
	}
	return r; // return 20;
}
```

#para_continue() is equivalent to:

```c
int main() {
	int r = 0;
	r += 1;
	r *= 2;
	r += 3;
	r *= 4;
	return r; // return 20;
}
```

#example() Defer statements#index[Defer statement] can be executed within a ```c switch```#index("Keywords", "switch", apply-casing: false, display: [```c switch```]), but a switch cannot be used to jump into the scope of a defer statement#index[defer statement].

```c
#include <stdlib.h>

int main() {
	void* p = malloc(1);
	switch (1) {
	defer free(p); // constraint violation
	default:
		defer free(p);
		break;
	}
	return 0;
}
```

#example() Defer statements#index[Defer statement] can not be exited by means of ```c break``` #index("Keywords", "break", apply-casing: false, display: [```c break```]) or ```c continue``` #index("Keywords", "continue", apply-casing: false, display: [```c continue```]).

```c
int main() {
	switch (1) {
	default:
		defer {
			break; // constraint violation
		}
	}
	for (;;) {
		defer {
			break; // constraint violation
		}
	}
	for (;;) {
		defer {
			continue; // constraint violation
		}
	}
	return 0;
}
```

#example() Defer statements#index[defer statement] that are not reached are not executed.

```c
#include <stdlib.h>

int main() {
	void* p = malloc(1);
	return 0;
	defer free(p); // not executed, p is leaked
}
```

#example() Defer statements#index[defer statement] can contain other compound statements.

```c
typedef struct meow *handle;

extern int purr(handle *h);
extern void un_purr(handle h);

int main() {
	handle h;
	int err = purr(&h);
	defer if (!err) un_purr(h);
	return 0;
}
```

== Predefined macro names #stable_tag("predef.macro") <predef.macro>

In addition to the keywords in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §6.10.10, an implementation shall define the following macro names:

/ `__STDC_DEFER_TS25755__`: The integer literal `1`.
#index(display: [```c __STDC_DEFER_TS__```], "macros", "__STDC_DEFER_TS__")

 

= Library #stable_tag("library") <library>

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 7 apply with additional requirements in this document.

== The `thrd_create` function #stable_tag("lib-thrd.create") <lib-thrd.create>
#index(apply-casing: false, display: [```c thrd_create```], "thrd_create")

In addition to the description and return requirements in in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §7.28.5.1, when the ```c thrd_start_t func``` parameter is returned from, it behaves as if it also runs any defer statements that are in scope for `func` before invoking ```c thrd_exit```#index(apply-casing: false, display: [```c thrd_exit```], "thrd_exit") with the returned value.

== Defer mechanism `<stddefer.h>` #stable_tag("lib-stddefer.hdr") <lib-stddefer.hdr>

A macro

```c
__STDC_VERSION_STDDEFER_H__
```

#para_continue() is an integer constant expression with the value ```c 202602L```.#index(apply-casing: false, display: [```c __STDC_VERSION_STDDEFER_H__```], "macros", "__STDC_VERSION_STDDEFER_H__")

=== Recommended practice

Implementations should provide a macro

```c
defer
```

#para_continue() which expands to ```c _Defer```#index(apply-casing: false, display: [```c _Defer```], "Keywords", "_Defer") in conjunction with the recommended practice in @keywords. This can aid in portability.
