#import "isoiec.typ": *
#import "@preview/in-dexter:0.7.0": *

#show: doc => isoiec(
	title: "Programming Languages — C — defer, a mechanism for general purpose, lexical scope-based undo",
	authors: ("JeanHeyd Meneide"),
	keywords: ("C", "defer", "ISO/IEC 9899", "Technical Specification", "Safety", "Resource"),
	id: "N3328",
	ts_id: "XYZW",
	abstract: [The advent of resource leaks in programs created with ISO/IEC 9899#index[ISO/IEC 9899] ⸺ Programming Languages, C has necessitated the need for better ways of tracking and automatically releasing resources in a given scope. This document provides a feature to address this need in a reliable, static, opt-in manner for implementations to furnish to programmers.],
	doc
)



= Scope

This Technical Specification specifies a series of extensions of the programming language C, specified by the international standard ISO/IEC 9899:2024#index[ISO/IEC 9899:2024].

Each clause in this Technical Specification deals with a specific topic. The first sub-clauses of clauses 4 through 7 contain a technical description of the features of the topic and what is necessary for an implementation to achieve conformance through modifications or additions to ISO/IEC 9899:2024#index[ISO/IEC 9899:2024].



= Normative References

The following documents are referred to in the text in such a way that some or all of their content constitutes requirements of this document. For dated references, only the edition cited applies. For undated references, the latest edition of the referenced document (including any amendments) applies.

#list(marker: [],
	[ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], Programming languages — C]
)



= Terms and definitions

For the purposes of this document, the terms and definitions of ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] apply.



= Conformance

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 4 apply without any additional requirements in this document.



= Environment

== General

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 5 apply along with the following additional requirements to support the ```c defer```#index(apply-casing: false, display: [```c defer```], "Keywords", "defer") feature.

== Program termination

*Semantics*

If the return type of the ```c main``` function is a type compatible with ```c int```, a return from the initial call to the main function is equivalent to calling the ```c exit``` function with the value returned by the ```c main``` function as its argument after all active defer statement#index[defer statement]s of the function body of main have been executed.
#index("program termination")




= Language

== General

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 6 apply along with the following additional requirements to support the ```c defer```#index(apply-casing: false, display: [```c `defer```], "Keywords", "defer") feature.

== Keywords

In addition to the keywords in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §6.4.2, an implementation shall additionally recognize ```c defer```#index(apply-casing: false, display: [```c defer```], "Keywords", "defer") as a keyword.

== Statements

In addition to the statements in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §6.8, implementations shall allow the unlabeled statement grammar production to produce a defer statement#index[defer statement].

*Syntax*

#h(1em) _unlabeled-statement_: \
#list(marker: none, indent: 8em,
	[_expression-statement_],
	[_attribute-specifier-sequence_#sub[opt] _primary-block_],
	[_attribute-specifier-sequence_#sub[opt] _jump-statement_],
	[_defer-statement_]
)
#index("unlabeled statement")
#index("defer statement")

== Defer statements

*Syntax*

#h(1em) _defer-statement_: \
#list(marker: none, indent: 8em,
	[`defer` _secondary-block_]
)
#index("defer statement")
#index(apply-casing: false, display: [```c defer```], "Keywords", "defer")

*Description*

Let _D_ be a defer statement#index[defer statement], _S_ be the secondary block of _D_ referred to as its deferred content, and _E_ be the enclosing block of _D_.

*Constraints*

Jumps by means of ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]) or ```c switch```#index("Keywords", "switch", apply-casing: false, display:[```c switch```]) shall not jump into any defer statement#index[defer statement].

Jumps by means of ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]) or ```c switch```#index("Keywords", "switch", apply-casing: false, display:[```c switch```]) into _E_ shall not jump over a defer statement#index[defer statement] in _E_.

Jumps by means of ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]) in _E_ shall not jump over a defer statement#index[defer statement] in _E_.

Jumps by means of ```c return```#index("Keywords", "return", apply-casing: false, display:[```c return```]) shall not exit _S_.

*Semantics*

When execution reaches a defer statement#index[defer statement] _D_, its _S_ is not immediately executed during sequential execution of the program. Instead, _S_ is executed upon:

- the termination of the block _E_ (such as from reaching its end);
- or, any exit from _E_ through ```c return```#index("Keywords", "return", apply-casing: false, display:[```c return```]), ```c goto```#index("Keywords", "goto", apply-casing: false, display:[```c goto```]), ```c break```#index("Keywords", "break", apply-casing: false, display:[```c break```]), or ```c continue```#index("Keywords", "continue", apply-casing: false, display:[```c continue```]).

The execution is done just before leaving the enclosing block _E_. In particular ```c return``` expressions (and conversion to return values)#index("conversions") are calculated before executing _S_.

Multiple defer statement#index[defer statement]s execute in the reverse lexical order they appeared in _E_. Within a single defer statement#index[defer statement] _D_, if _D_ contains one or more defer statement#index[defer statement]s of its own, then these defer statement#index[defer statement]s are also executed in reverse lexical order at the end of _S_, recursively, according to the rules of this clause.

If _E_ has any defer statement#index[defer statement]s _D_ that have been reached and their _S_ have not yet executed, but the program is terminated or leaves _E_ through any means including:

- a function with the deprecated `_Noreturn` function specifier, or a function annotated with the `noreturn` or `_Noreturn` attribute, is called#index(initial: "n", display: [`_Noreturn`], apply-casing: false, "_Noreturn")#index(apply-casing: false, display: [`noreturn`], "noreturn");
- or, any signal `SIGABRT`, `SIGINT`, or `SIGTERM` occurs#index("signal");

then any such _S_ are not run, unless otherwise specified by the implementation. Any other _D_ that have not been reached are not run.

#note() The execution of deferred statements upon non-local jumps (i.e., `longjmp` and `setjmp` described in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §7.13)#index("non-local jump") or program termination is a technique sometimes known as "unwinding" or "stack unwinding", and some implementations perform it. See also ISO/IEC 14882#index[ISO/IEC 14882] Programming languages — C++ [except.ctor].

If a non-local jump #index("non-local jump") is used within _E_ but before the execution of _D_:

- if execution leaves _E_, _S_ will not be executed;
- otherwise, if control returns to a point in _E_ and causes _D_ to be reached more than once, there is no effect.

#note() The "execution" of a defer statement#index[defer statement] only lets the program know that _S_ will be run on any exit from that scope. There is no observable side effect to repeat from reaching _D_, as the manifestation of any of the effects of _S_ will happen if and only if _E_ is exited or terminated as previously specified.


If a non-local jump #index("non-local jump") is executed from _S_ and control leaves _S_, the behavior is unspecified#index("unspecified behavior").

If a non-local jump #index("non-local jump") is executed outside of any _D_ and:

- it jumps into any _S_;
- or, it jumps over any _D_;

the behavior is unspecified#index("unspecified behavior").

#example() Defer statement#index[Defer statement]s cannot be jumped over.#index("Keywords", "goto", apply-casing: false, display:[```c goto```])

```c
#include <stdio.h>

int f () {
	goto b; // constraint violation
	defer { printf(" meow"); }
	b:
	printf("cat says");
	return 1;
}

int g () {
	return printf("cat says");
	defer { printf(" meow"); } // okay: no constraint violation, not executed
	// print "cat says" to standard output
}

int h () {
	goto b;
	{
		// okay: no constraint violation
		defer { printf(" meow"); }
	}
	b:
	printf("cat says");
	return 1; // prints "cat says" to standard output
}

int i () {
	{
		defer { printf("cat says"); }
		// okay: no constraint violation
		goto b;
	}
	b:
	printf(" meow");
	return 1; // prints "cat says meow" to standard output
}

int j () {
	defer {
		goto b; // okay: no constraint violation
		printf(" meow");
	}
	b:
	printf("cat says");
	return 1; // prints "cat says" over
	// and over again to standard output
}

int k () {
	defer {
		return 5; // constraint violation
		printf(" meow");
	}
	printf("cat says");
	return 1;
}

int l () {
	defer {
		b:
		printf(" meow");
	}
	goto b; // constraint violation
	printf("cat says");
	return 1;
}

int m () {
	goto b; // okay: no constraint violation
	{
		b:
		defer { printf("cat says"); }
	}
	printf(" meow");
	return 1; // prints "cat says meow" to standard output
}

int n () {
	goto b; // constraint violation
	{
		defer { printf(" meow"); }
		b:
	}
	printf("cat says");
	return 1;
}

int o () {
	{
		defer printf("cat says");
		goto b;
	}
	b:;
	printf(" meow");
	return 1; // prints "cat says meow"
}

int p () {
	{
		goto b;
		defer printf(" meow");
	}
	b:;
	printf("cat says");
	return 1; // prints "cat says"
}
```

#example() All the expressions and statements of an enclosing block are evaluated before executing defer statement#index[defer statement]s, including any conversions#index[conversions]. After all defer statement#index[defer statement]s are executed, the block is then exited.

```c
int main () {
	int r = 4;
	int* p = &r;
	defer { *p = 5; }
	return *p; // return 4;
}
```

Conversions#index("conversions") for the purposes of return are also computed before ```c defer```#index(apply-casing: false, display: [```c defer```], "Keywords", "defer") is entered.

```c
#include <float.h>
#include <assert.h>

bool f () {
	double x = DBL_SNAN;
	defer {
		// fetestexcept (FE_INVALID) is nonzero because of the
		// comparison during the conversion to bool
		assert(ftestexcept(FE_INVALID) != 0);
	}
	return x;
}
```

#example() It is implementation-defined if defer statement#index[defer statement]s will execute if the exiting / non-returning functions detailed previously#index("program termination") are called.

```c
#include <stdio.h>
#include <stdlib.h>

int f () {
	void* p = malloc(1);
	if (p == NULL) {
		return 0;
	}
	defer free(p);
	exit(1); // "p" may be leaked
	return 1;
}

int main () {
	return f();
}
```

#example() Defer statement#index[Defer statement]s, when execution reaches them, are tied to their enclosing block.

```c
#include <stdio.h>
#include <stdlib.h>

int main () {
	{
		defer {
			printf(" meow");
		}
		if (true)
			defer printf("cat");
		printf(" says");
	}
	// "cat says meow" is printed to standard output
	exit(0);
}
```

#example() Defer statement#index[Defer statement]s execute in reverse lexical order, and nested defer statement#index[defer statement]s execute in reverse lexical order but at the end of the defer statement#index[defer statement] they were invoked within. The following program:

```c
int main () {
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

is equivalent to:

```c
int main () {
	int r = 0;
	r += 1;
	r *= 2;
	r += 3;
	r *= 4;
	return r; // return 20;
}
```

#example() Defer statement#index[Defer statement]s can be executed within a ```c switch```#index("Keywords", "switch", apply-casing: false, display: [```c switch```]), but a switch cannot be used to jump over a defer statement#index[defer statement].

```c
#include <stdlib.h>

int main () {
	void* p = malloc(1);
	switch (1) {
	defer free(p); // constraint violation
	default:
		defer free(p);
		break;
	}
	return 2;
}
```

#example() defer statement#index[defer statement]s that are not reached are not executed.

```c
#include <stdlib.h>

int main () {
	void* p = malloc(1);
	return 0;
	defer free(p); // not executed, p is leaked
}
```

#example() defer statement#index[defer statement]s can contain other compound statements.

```c
typedef struct meow *handle;

extern int purr (handle *h);
extern void un_purr(handle h);

int main () {
	handle h;
	int err = purr(&h);
	defer if (!err) un_purr(h);
	return 0;
}
```


== Predefined macro names

In addition to the keywords in ISO/IEC 9899:2024#index[ISO/IEC 9899:2024] §6.10.10, an implementation shall define the following macro names:

/ `__STDC_DEFER_TS___`: The integer literal `1`.
#index(display: [```c __STDC_DEFER_TS__```], "macros", "__STDC_DEFER_TS__")



= Library

The requirements from ISO/IEC 9899:2024#index[ISO/IEC 9899:2024], clause 7 apply without any additional requirements in this document.

#heading(
	numbering: none,
	[Index]
)
#columns(2)[
	#set text(size: 0.85em)
	#show heading: it => block[
		#it.body
		#v(0.25em)
	]
	#make-index(title: none)
]