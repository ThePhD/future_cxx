---
title: Restartable and Non-Restartable Functions for Efficient Character Conversions | r4
date: May 22nd, 2021
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis) \<<shepherd@soasis.org>\>
layout: paper
hide: true
---

_**Document**_: n2730  
_**Previous Revisions**_: n2431, n2440, n2500, n2595, n2620  
_**Audience**_: WG14  
_**Proposal Category**_: New Library Features  
_**Target Audience**_: General Developers, Text Processing Developers  
_**Latest Revision**_: [https://thephd.dev/_vendor/future_cxx/papers/C%20-%20Efficient%20Character%20Conversions.html](https://thephd.dev/_vendor/future_cxx/papers/C%20-%20Efficient%20Character%20Conversions.html)


<div class="text-center">
<h5>Abstract:</h5>
<p>
Implementations firmly control what both the Wide Character and Multibyte Character literals are interpreted as for the encoding, as well as how they are treated at runtime by the Standard Library. While this control is fine, users of the Standard Library have no portability guarantees about how these library functions may behave, especially in the face of encodings that do not support each other's full codepage. And, despite additions to C11 for maybe-UTF16 and maybe-UTF32 encoded types, these functions only offer conversions of a single unit of information at a time, leaving orders of magnitude of performance on the table.
</p>
<p>
This paper proposes and explores additional library functionality to allow users to retrieve multibyte and wide character into a statically known encoding to enhance the ability to work with text.
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 5 - May 15th, 2021

- Benchmark 2 different styles of function declaration and discuss benefits.



## Revision 4 - December 1st, 2020

- Add missing functions for c8/16/32 to the platform-specific variants.
- Ensure that `mbstate_t` is used throughout rather than `mcstate_t`.
- Explain behavior of `NULL` for `mbstate_t` to avoid use of global values.



## Revision 3 - October 27th, 2020

- Completely Reformulate Paper based on community, musl-libc, and glibc feedback.
- Completely rewrite every section past [Proposed Changes](#proposed-changes), and change many more.



## Revision 0-2 - March 2nd, 2020

- Introduce new functions and gather consensus to move forward.
- Attempt to implement in other standard libraries and gather feedback.




# Introduction and Motivation {#intro}

C adopted conversion routines for the current active locale-derived/`LC_TYPE`-controlled/implementation-defined encoding for Multibyte (`mb`) Strings and Wide (`wc`) Strings. While the rationale for having such conversion routines to and from Multibyte and Wide strings in the C library are not explicitly stated in the documents, it is easy to derive the many benefits of a full ecosystem of both restarting (`r`) and non-restarting conversion routines for both single units and string-based bulk conversions for `mb` and `wc` strings. From ease of use with string literals to performance optimizations from bulk processing with vectorization and SIMD operations, the `mbs(r)towcs` — and vice-versa — granted a rich and fertile ground upon which C library developers took advantage of platform amenities, encoding specifics, and hardware support to provide useful and fast abstractions upon which encoding-aware applications could build.

Unfortunately, none of these API designs were granted to `char16_t` (`c16`) or `char32_t` (`c32`) conversion functions. Nor were they given a way to work with a well-defined 8-bit multibyte encoding such as UTF8 without having to first pin it down with platform-specific `setlocale(...)` calls. This has resulted in a series of extremely vexing problems when trying to write a portable, reliable C library code that is not locked to a specific vendor.

This paper looks at the problems, and then proposes a solution (without C Standard wording) with the goal of hoping to arrive at a solution that is worth implementing for the C Standard Library.



## Problem 1: Lack of Portability {#intro-problem-portability}

Already, Windows, z/OS, and POSIX platforms greatly differ in what they offer for `char`-typed, Multibyte string encodings. EBCDIC is still in play after many decades. Windows's Active Code Page functionality on its machine prevents portability even within its own ecosystem. Platforms where LANG environment variables control functionality make communication between even processes on the same hardware a silent and often unforeseen gamble for library developers. Using functions which convert to/from `mbs` make it impossible to have stability guarantees not only between platforms, but for individual machines. Sometimes even cross-process communication becomes exceedingly problematic without opting into a serious amount of platform-specific or vendor-specific code and functionality to lock encodings in, harming the portability of C code greatly.

`wchar_t` does not fare better. By definition, a wide character type must be capable of holding the entire character set in a single unit of `wchar_t`. Reality, however, is different: this has been a fundamental impossibility for decades for implementers that switched to 16-bit UCS-2 early. IBM machines persist with this issue for all 32-bit builds, though some IBM platforms took advantage of the 64-bit change to do an ABI break and use UTF32 like other Linux distributions settled on. Even if one were to know this knowledge about IBM and program exclusively on their machines, certain IBM platforms can still end up in a situation where `wchar_t` is neither 32-bit UTF32 or 16-bit UCS-2/UTF16: the encoding can change to something else in certain Chinese locales, becoming completely different.

Windows is permanently stuck on having to explicitly detail that its implementation is "16-bit, UCS-2 as per the standard", before explicitly informing developers to use vendor-specific `WideCharToMultibyte`/`MultibyteToWideChar` to handle UTF16-encoded characters in `wchar_t`.

These solutions provide ways to achieve a local maxima for a specific vendor or platform. Unfortunately, this comes at the extreme cost of portability: the code has no guarantee it will work anywhere but your machine, and in a world that is increasingly interconnected by devices that interface with networks it makes sharing both data and code troublesome and hard to work with.



## Problem 2: What is the Encoding? {#intro-problem-what}

With `setlocale` and `getlocale` only responding to and returning implementation-defined `(const )char*`, there is no way to portably determine what the locale (and any associated encoding) should or should not be. The typical solution for this has been to code and program only for what is guaranteed by the Standard as what is in the Basic Character Set. While this works fine for source code itself, this produces an extremely hostile environment:

- conversion functions in the standard mangle and truncate data in (sometimes troubling, sometimes hilarious) fashion;
- programs which are not careful to meticulously track encoding of incoming text often lose the ability to understand that text;
- programmers can never trust the platform will support even the Latin characters in any representation of data beyond the 7th bit of a byte;
- and, interchange between cultures with different default encodings makes it impossible to communicate with others without entirely forsaking the standard library.

Abandoning the C __Standard__ Library -- to get __standard__ behavior across platforms -- is an exceedingly bitter pill to have to swallow as an enthusiastic C developer.



## Problem 3: Performance {#intro-problem-performance}

The current version of the C Standard includes functions which attempt to alleviate Problems 1 and 2 by providing conversions from the per-process (and sometimes per-thread), locale-sensitive black box encoding of multibyte `char*` strings. They do this by providing conversions to `char16_t` units or `char32_t` units with `mbrtoc(16|32)` and `c(16|32)rtomb` functions. We will for a brief moment ignore the presence of the `__STD_C_UTF16__` and `__STD_C_UTF32__` macros and assume the two types mean that string literals and library functions convert to and from UTF16 and UTF32 respectively. We will also ignore that `wchar_t`'s encoding -- which is just as locale-sensitive and unknown at compile and runtime as `char`'s encoding is -- has no such conversion functions. These givens make it possible to say that we, as C programmers, have 2 known encodings which we can use to shepherd data into a stable state for manipulation and processing as library developers.

Even with that knowledge, these one-unit-at-a-time conversions functions are slower than they should be.

On many platforms, these one-at-a-time function calls come from the operating system, dynamically loaded libraries, or other places which otherwise inhibit compiler observation and optimizer inspection. Attempts to vectorize code or unroll loops built around these functions is thoroughly thwarted by this. Building static libraries or from source is very often a non-starter for many platforms. Since the encoding used for multibyte strings and wide strings are controlled by the implementation, it becomes increasingly difficult to provide the functionality to convert long segments of data with decent performance characteristics without needing to opt into vendor or platform specific tricks.



## Problem 4: `wchar_t` Cannot Roundtrip {#intro-problem-roundtrip}

With no `wctoc32` or `wctoc16` functions, the only way to convert a wide character or wide character string to a program-controlled, statically known encoding UTF encoding is to first invoke the wide character to multibyte function, and then invoke the multibyte function to either `char16_t` or `char32_t`.

This means that even if we have a well-behaved `wchar_t` that is not sensitive to the locale (e.g., on Windows machines), we lose data if the locale-controlled `char` encoding is not set to something that can handle all incoming code unit sequences. The locale-based encoding in a program can thus tank what is simply meant to be a pass-through encoding from `wchar_t` to `char16_t`/`char32_t`, all because the only Standards-compliant conversion channels data through the locale-based multibyte encoding `mb(s)(r)toX(s)` functions.

For example, it was fundamentally impossible to engage in a successful conversion from `wchar_t` strings to `char` multibyte strings on Windows using the C Standard Library. Until a very recent Windows 10 update, UTF8 could **not** be set as the active system codepage either programmatically or through an experimental, deeply-buried setting. This has changed with Windows Version 1903 (May 2019 Update), but the problems do not stop there.

No dedicated UTF-8 support (the standard mandates no specific encodings or charsets) leaves developers to write the routines themselves. Sometimes worse,  roundtrip it through the locale after forcing a change to a UTF-8 locale, which may not be supported. While the non-restartable functions can save quite a bit of code size, unfortunately there are many encodings which are not as nice and require state to be processed correctly (e.g., Shift JIS and other ISO-2022 encodings). Not being able to retain that state between potential calls in a `mbstate_t` is detrimental to the ability to move forward with any encoding endeavor that wishes to bridge the gap between these disparate platform encodings and the current locale.

Because other library functions can be used to change or alter the locale in some manner, it once again becomes impossible to have a portable, compliant program with deterministic behavior if just one library changes the locale of the program, let alone if the encoding or locale is unexpected by the developer because they do not know of that culture or its locale setting. This hidden state is nearly impossible to account for: the result is software systems that cannot properly handle text in a meaningful way without abandoning C's encoding facilities, relying on vendor-specific extensions/encodings/tools, or confining one's program to only the 7-bit plane of existence.



## Problem 5: The C Standard Cannot Handle Existing Practice {#intro-problem-standard}

The C standard does not allow a wide variety of encodings that implementations have already crammed into their backing locale blocks to work, resulting in the abandonment of locale-related text facilities by those with double-byte character sets, primarily from East Asia. For example, there is a serious bug that cannot be fixed without non-conforming, broken behavior[^glibc-25744]:

> ...
> 
> This call writes the second Unicode code point, but does not consume
> any input. 0 is returned since no input is consumed. According to
> the C standard, a return of 0 is reserved for when a null character is
> written, but since the C standard doesn't acknowledge the existence of
> characters that can't be represented in a single `wchar_t`, we're already
> operating outside the scope of the standard.

The standard cannot handle encodings that must return two or more `wchar_t` for however many -- up to `MB_MAX_LEN` -- it consumes. This is even for when the target `wchar_t` "wide execution" encoding is UTF-32; this is a **fundamental limitation of the C Standard Library that is absolutely insurmountable by the current specification**. This is exacerbated by the standard's insistence that a single `wchar_t` must be capable of representing all characters as a single element, a philosophy which has been bled into the relevant interfaces such as `mbrtowc` and other `*wc*` related types. As the values cannot be properly represented in the standard, this leaves people to either make stuff up or abandon it altogether. This means that the design introduced from C11[^N1570] and beyond is fundamentally broken when it comes to handling existing practice.

Furthermore, clarification requests have had to be filed for other functions, just to improve their behavior with respect to multiple input and multiple output[^N2244]. Many have been noted as issues for `mbrtoc16` and similar functionality, as was originally part of Dr. Philip K. Krause's fixes to the functions[^N2282]. This paper attempts to solve the same problem in a more fundamental manner.



## In Summary {#intro-summary}

The problems C developers face today with respect to encoding and dealing with vendor and platform-specific black boxes is a staggering trifecta: non-portability between processes running on the same physical hardware, performance degradation from using standard facilities, and potentially having a locale changed out from under your program to prevent roundtripping.

This serves as the core motivation for this proposal.




# Prior Art {#prior}

There are many sources of prior art for the desired feature set. Some functions (with fixes) were implemented directly in implementations, embedded and otherwise. Others rely exclusively platform-specific code in both Windows and POSIX implementations. Others have cross-platform libraries that work across a myriad of platforms, such as ICU or iconv. We discuss the most diverse and exemplary implementations.



## Standard C {#prior-standard}

To understand what this paper proposes, an explanation of the current landscape is necessary. The below table is meant to be read as being `{row}to{column}`. The symbols provide the following information:

- ✔️: Function exists in both its restartable (function name has the indicative `r` in it) and its canonical non-restartable form (`{row}to{column}` and `{row}rto{column}`).
- 🇷: Function exists only in its "restartable" form (`{row}rto{column}`).
- ❌: Function does not exist at all.

Here is what exists in the C Standard Library so far:

<table class="feature-emoji">
  <tr>
    <th class="feature-emoji-cell"></th>
    <th class="feature-emoji-cell">mb</th>
    <th class="feature-emoji-cell">wc</th>
    <th class="feature-emoji-cell">mbs</th>
    <th class="feature-emoji-cell">wcs</th>
    <th class="feature-emoji-cell">c8</th>
    <th class="feature-emoji-cell">c16</th>
    <th class="feature-emoji-cell">c32</th>
    <th class="feature-emoji-cell">c8s</th>
    <th class="feature-emoji-cell">c16s</th>
    <th class="feature-emoji-cell">c32s</th>
  </tr>
  <tr>
    <td class="feature-emoji-cell">mb</td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"> 🇷 </td>
    <td class="feature-emoji-cell">🇷</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">wc</td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">mbs</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">wcs</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c8</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c16</td>
    <td class="feature-emoji-cell">🇷</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c32</td>
    <td class="feature-emoji-cell">🇷</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c8s</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌<br></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c16s</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">➖</td>
    <td class="feature-emoji-cell">❌</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c32s</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">❌</td>
    <td class="feature-emoji-cell">➖</td>
  </tr>
</table>

There is a lot of missing functionality here in this table, and it is important to note that a large amount of this comes from both not being willing to standardize more than the bare minimum and not having a cohesive vision for improving encoding conversions in the C Standard. Notably, string-based `{prefix}s` functions are missing, leaving performance-oriented multi-unit conversions out of the standard. There are also severe API flaws in the C standard, [as discussed above](#intro-problem-standard).



## Win32 {#prior-win32}

`WideCharToMultiByte` and `MultiByteToWideChar` are the APIs of choice for those in Win32 environments to get to and from the run-time execution encoding and -- if it matches -- the translation-time execution encoding. Unfortunately, these APIs are locked within the Windows ecosystem entirely as they are not available as a standalone library. Furthermore, as an operating system Windows exclusively controls what it can and cannot convert from and to; some of these functions power the underlying portions of the character conversion functions in their Standard Library, but they notably truncate multi-code-unit characters for their UTF-16 `wchar_t`. This produces a broken, deprecated UCS-2 encoding when e.g. `mbrtowc` is used instead of directly relying on the operating system functionality, making the C standard's functions of dubious use.



## `nl_langinfo` {#prior-nl_langinfo}

`nl_langinfo` is a POSIX function that returns various pieces of information based on an enumerated input and some extra parameters. It has been suggested that this be standardized over anything else, to make it easier to determine what to do with a given locale.

The first problem with this is it returns a string-based identifier that can be whatever an implementation decides it should be. This makes `nl_langinfo` is no better than `setlocale(LC_CHARSET, NULL)` in its design:

> Specifies the name of the coded character set for which the **charmap** file is defined. This value determines the value returned by the `nl_langinfo` subroutine. The `<code_set_name>` must be specified using any character from the portable character set, except for control and space characters.

Any name can be chosen that fits this description, and POSIX nails nothing down for portability or identification reasons. There is no canonical list, just whatever implementations happen to supply as their "charmap" definitions.



## SDCC {#prior-sdcc}

The Small Device C Compiler (SDCC) has already begun some of this work. One of its principle contributors, Dr. Philip K. Krause, wrote papers addressing exactly this problem[^N2282]. Krause's work focuses entirely on non-restartable conversions from Multibyte Strings to `char16_t` and `char32_t`. There is no need for a conversion to a UTF8 `char` style string for SDCC, since the Multibyte String in SDCC is always UTF8. This means that `mbstoc16s` and `mbstoc32s` and the "reverse direction" functions encompass an entire ecosystem of UTF8, UTF16, and UTF32.

While this is good for SDCC, this is not quite enough for other developers who attempt to write code in a cross-platform manner.

Nevertheless, SDCC's work is still important: it demonstrates that these functions are implementable, even for small devices. With additional work being done to implement them for other platforms, there is strong evidence that this can be implemented in a cross-platform manner and thusly is suitable for the Standard Library.



## iconv/ICU {#prior-iconv}

The C functions presented below is motivated primarily by concepts found in a popular POSIX library, [iconv](https://www.gnu.org/software/libiconv/)[^iconv]. We do not provide the full power of iconv here but we do mimic its interface to allow for a better definition of functions, as explained in [Problem 5](#intro-problem-standard). The core of the functionality can be embodied in this parameterized function signature:

```cpp
mchar_error XstoYs(const charX** input, size_t* input_bytes, const charY** output, size_t* output_bytes);
```

In `iconv`'s case, an additional first parameter describing the conversion (of type `iconv_t`). That is not needed for this proposal, because we are not making a generic conversion API. This proposal is focused on doing 2 things and doing them extremely well:

- Getting data from the current execution encoding (`char`) to a Unicode encoding (`unsigned char`/UTF-8, `char16_t`/UTF-16, `char32_t`/UTF-32), and the reverse.
- Getting data from the current wide execution encoding (`wchar_t`) to a Unicode encoding (`unsigned char`/UTF-8, `char16_t`/UTF-16, `char32_t`/UTF-32), and the reverse.

iconv can do the above conversions, but also supports a complete list of pairwise conversions between about 49 different encodings. It can also be extended at translation time by programming more functionality into its library. This proposal is focusing just in doing conversions to and from encodings that the implementation owns to/from Unicode. This results in the design found [below](#proposed-functions).

<div class="pagebreak"></div>




# Solution {#solution}

Given the problems before, the prior art, the implementation experience, and the vendor experience, it is clear that we need something outside of `nl_langinfo`, lighter weight than all of `iconv`, and more resilient and encompassing than what the C Standard offers. Therefore, the solution to our problem of having a wide variety of implementation encodings is to expand the contract of `wchar_t` for an **entirely new set of functions** which avoid the problems and pitfalls of the old mechanism.

Notably, both of the multibyte string's function design and the wide character string's definition of a single character is broken in terms of existing practice today. The primary problem relies in the inability for both APIs in either direction to handle `N:M` encodings, rather than `N:1` or `1:M`. Therefore, these new functions focus on providing an interface to allow multi-code-unit conversions, in both directions.

To facilitate this, new headers -- `<stdmchar.h>` -- will be introduced. Each header will contain the "multi character" (`mc`) and "multi wide character" (`mwc`) conversion routines, respectively. To support getting data losslessly out of `wchar_t` and `char` strings controlled firmly by the implementation -- and back into those types if the code units in the characters are supported -- the following functionality is proposed using the new multi (wide) character (`m[w]c`) prefixes and suffixes:

<table class="feature-emoji">
  <tr>
    <th class="feature-emoji-cell"></th>
    <th class="feature-emoji-cell">mc</th>
    <th class="feature-emoji-cell">mwc</th>
    <th class="feature-emoji-cell">mcs</th>
    <th class="feature-emoji-cell">mwcs</th>
    <th class="feature-emoji-cell">c8</th>
    <th class="feature-emoji-cell">c16</th>
    <th class="feature-emoji-cell">c32</th>
    <th class="feature-emoji-cell">c8s</th>
    <th class="feature-emoji-cell">c16s</th>
    <th class="feature-emoji-cell">c32s</th>
  </tr>
  <tr>
    <td class="feature-emoji-cell">mc</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">mwc</td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">mcs</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">mwcs</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c8</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c16</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c32</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c8s</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c16s</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
  </tr>
  <tr>
    <td class="feature-emoji-cell">c32s</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell"></td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
    <td class="feature-emoji-cell">🅿️✔️</td>
  </tr>
</table>

In particular, it is imperative to recognize that the implementation is the "sole proprietor" of the wide locale encodings and multibyte locale encodings for its string literals (compiler) and library functions (standard library). Therefore, the `mc` and `mwc` functions simply focus on providing a good interface for these encodings. The form of both the individual and string conversion functions are:

```cpp
mchar_error XntoYn(const charX** input, size_t* input_size,
              const charY** output, size_t* output_size);
mchar_error XnrtoYn(const charX** input, size_t* input_size,
               const charY** output, size_t* output_size, mbstate_t* state);
mchar_error XsntoYsn(const charX** input, size_t* input_size,
                const charY** output, size_t* output_size);
mchar_error XsnrtoYsn(const charX** input, size_t* input_size,
                 const charY** output, size_t* output_size, mbstate_t* state);
```

The input and output sizes are expressed in terms of the # of `charX`/`charY`s. They take the input/output sizes as pointers, and decrement the value by the amount of input/output consumed. Similarly, the input/output data pointers themselves are incremented by the amount of spaces consumed / written to. This only happens when an irreversible and successful conversion of input data can successfully and without error be written to the output. The `s` functions work on whole strings rather than just a single complete irreversible conversion, the `n` stands for taking a size value.

Input is consumed and output is written (with sizes updated) in accordance with a single, successful computation of an _indivisible unit of work_. An _indivisible unit of work_ is the smallest set of input that can be consumed that produces no error and guarantees forward progress through the input buffer. No output is guaranteed to occur (e.g., during the consumption of a shift state mechanism for e.g. SHIFT-JIS), but if output does happen then it only occurs upon the successful completion of an _indivisible unit of work_.

If an error happens, the conversion is stopped and an error code is returned. The function does not decrement the input or output sizes for the failed operation, nor does it shift the input and output pointers forward for the failed operation. "Failed operation" refers to a single, indivisible unit of work. The error codes are as follows:

- `mchar_error_insufficient_output = (size_t)-3` \| the input is correct but there is not enough output space
- `mchar_error_incomplete_input    = (size_t)-2` \| an incomplete input was found after exhausting the input
- `mchar_error_invalid      = (size_t)-1` \| an encoding error occurred
- `mchar_error_ok                  = (size_t) 0` \| the operation was successful

The behaviors are as follows:

- if `output` is `NULL`, then no output will be written. If `*output_size` is not-`NULL`, the value will be decremented the amount of characters that would have been written.
- if `output` is non-`NULL` and `output_size` is `NULL`, then enough space is assumed in the output buffer for the entire operation
- for the restartable (`r`) functions, if `input` is `NULL` and `state` is not-`NULL`, then `state` is set to the initial conversion sequence and no other actions are performed; otherwise, `input` must not be `NULL`.
- for the non-restartable functions (without `r`), it behaves as if:
  - a non-`static` `mbstate_t` object is initialized to the initial conversion sequence;
  - and, a pointer to this state object plus the original four parameters are passed to the restartable version of the function.

Finally, it is useful to prevent the class of `(size_t)-3` errors from showing up in your code if you know you have enough space. For the non-string (the functions lacking `s`) that perform a single conversion, a user can pre-allocate a suitably sized static buffer in automatic storage duration space. This will be facilitated by a group of integral constant expressions contained in macros, which would be;

- `STDC_MC_MAX`, which is the maximum output for a call to one of the X to multi character functions
- `STDC_MWC_MAX`, which is the maximum output for a call to one of the X to multi wide character functions
- `STDC_MC8_MAX`, which is the maximum output for a call to one of the X to UTF-8 character functions
- `STDC_MC16_MAX`, which is the maximum output for a call to one of the X to UTF-16 character functions
- `STDC_MC32_MAX`, which is the maximum output for a call to one of the X to UTF-32 character functions

these values are suitable for use as the size of an array, allowing a properly sized buffer to hold all of the output from the non-string functions. These limits apply **only** to the non-string functions, which perform a single unit of irreversible input consumption and output (or fail with one of the error codes and outputs nothing).

Here is the full list of proposed functions:

```cpp
#include <stdmchar.h>

#define STDC_C8_MAX  4
#define STDC_C16_MAX 2
#define STDC_C32_MAX 1
#define STDC_MC_MAX  1
#define STDC_MWC_MAX 1

enum mchar_error {
  mchar_error_ok                  =  0;
  mchar_error_invalid             = -1;
  mchar_error_incomplete_input    = -2;
  mchar_error_insufficient_output = -3;
};

mchar_error mcntomcn(const char** input, size_t* input_size, char** output, size_t* output_size);
mchar_error mcnrtowcn(const char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error mcntomwcn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error mcnrtomwcn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error mcntoc8n(const char** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error mcnrtoc8n(const char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error mcntoc16n(const char** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error mcnrtoc16n(const char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error mcntoc32n(const char** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error mcnrtoc32n(const char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error mwcntomcn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error mwcnrtomcn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error mwcntomwcn(const wchar_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error mwcnrtomwcn(const wchar_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error mwcntoc8n(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error mwcnrtoc8n(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error mwcntoc16n(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error mwcnrtoc16n(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error mwcntoc32n(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error mwcnrtoc32n(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error c8ntomcn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size);
mchar_error c8nrtomcn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error c8ntomwcn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error c8nrtomwcn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error c8ntoc8n(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error c8nrtoc8n(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error c8ntoc16n(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error c8nrtoc16n(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error c8ntoc32n(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error c8nrtoc32n(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error c16ntomcn(const char16_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error c16nrtomcn(const char16_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error c16ntomwcn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error c16nrtomwcn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error c16ntoc8n(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error c16nrtoc8n(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error c16ntoc16n(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error c16nrtoc16n(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error c16ntoc32n(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error c16nrtoc32n(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error c32ntomcn(const char32_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error c32nrtomcn(const char32_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error c32ntomwcn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error c32nrtomwcn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error c32ntoc8n(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error c32nrtoc8n(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error c32ntoc16n(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error c32nrtoc16n(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error c32ntoc32n(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error c32nrtoc32n(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error mcsntomcsn(const char** input, size_t* input_size, char** output, size_t* output_size);
mchar_error mcsnrtomcsn(const char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error mcsntomwcsn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error mcsnrtomwcsn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error mcsntoc8sn(const char** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error mcsnrtoc8sn(const char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error mcsntoc16sn(const char** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error mcsnrtoc16sn(const char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error mcsntoc32sn(const char** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error mcsnrtoc32sn(const char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error mwcsntomcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error mwcsnrtomcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error mwcsntomwcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error mwcsnrtomwcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error mwcsntoc8sn(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error mwcsnrtoc8sn(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error mwcsntoc16sn(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error mwcsnrtoc16sn(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error mwcsntoc32sn(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error mwcsnrtoc32sn(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error c8sntomwcsn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error c8snrtomwcsn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error c8sntomcsn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size);
mchar_error c8snrtomcsn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error c8sntoc8sn(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error c8snrtoc8sn(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error c8sntoc16sn(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error c8snrtoc16sn(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error c8sntoc32sn(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error c8snrtoc32sn(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error c16sntomwcsn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error c16snrtomwcsn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error c16sntomcsn(const char16_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error c16snrtomcsn(const char16_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error c16sntoc8sn(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error c16snrtoc8sn(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error c16sntoc16sn(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error c16snrtoc16sn(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error c16sntoc32sn(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error c16snrtoc32sn(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);

mchar_error c32sntomcsn(const char32_t** input, size_t* input_size, char** output, size_t* output_size);
mchar_error c32snrtomcsn(const char32_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
mchar_error c32sntomwcsn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
mchar_error c32snrtomwcsn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
mchar_error c32sntoc8sn(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
mchar_error c32snrtoc8sn(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
mchar_error c32sntoc16sn(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size);
mchar_error c32snrtoc16sn(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
mchar_error c32sntoc32sn(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size);
mchar_error c32snrtoc32sn(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
```



# Conclusion

The ecosystem deserves ways to get to a statically-known encoding and not rely on implementation and locale-parameterized encodings. This allows developers a way to perform cross-platform text processing without needing to go through fantastic gymnastics to support different languages and platforms. An independent library implementation, _cuneicode_[^unicode_greater_detail] [^unicode_deep_c_diving], is available upon request to the author. A patch to major libraries will be worked on once more after some affirmation of the direction.




# Proposed Changes {#wording}

The following wording is relative to [N2573](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf).



## Intent {#proposed-intent}

The intent of the wording is to provide transcoding functions that:

- define "code unit" as the smallest piece of information;
- define the notion of an "indivisible unit of work";
- introduce the notion of multi-unit work that does not use the same 1:N or M:1 design as the precious `wchar_t` functions;
- convert from the execution ("mc") and wide execution ("mwc") encodings to the unicode ("c8", "c16", "c32") encodings and vice-versa;
- convert from the execution encoding ("mc") to the wide execution ("mwc") encoding and vice-versa;
- provide a way for `mbstate_t` to be properly initialized as the initial conversion sequence; and,
- to be entirely thread-safe by default with no magic internal state asides from what is already required by locales.



## Proposed Library Wording {#proposed-wording}

_Author's Note: Any � is a stand-in character to be replaced by the editor._


### Create a new section 7.S� Text Transcoding Utilities

<blockquote>
<div class="wording-section">
<ins>
<p><h4><b>7.S� &emsp; Text transcoding utilities &lt;stdmchar.h&gt;</b></h4></p>

<div class="wording-numbered"><p>
The header &lt;stdmchar.h&gt; declares four status codes, five macros, several types and several functions for transcoding encoded text safely and effectively. It is meant to supersede and obsolete text conversion utilities from Unicode utilities (7.28) and Extended multibyte and wide character utilities (7.29). It is meant to represent "multi character" functions. These functions can be used to count the number of input that form a complete sequence, count the number of output characters required for a conversion with no additional allocation, validate an input sequence, or just convert some input text. Particularly, it provides single unit and multi unit output functions for transcoding by working on <i>code units</i>.
</p></div>

<div class="wording-numbered"><p>
A code unit is a single compositional unit of encoded information, usually of type <code class="c-kw">char</code>, <code class="c-kw">unsigned char</code>, <code class="c-kw">char16_t</code>, <code class="c-kw">char32_t</code>, or <code class="c-kw">wchar_t</code>. One or more code units are interpreted in a specific way specified by the related encoding of the operation. They are read until enough input to perform an <i>indivisible unit of work</i>. An indivisible unit is the smallest possible input, as defined by the encoding, that can produce either one or more outputs or perform a transformation of some internal state. The production of these indivisible units is called an <i>indivisible unit of work</i>, and they are used to complete the below specified transcoding operations. When an <i>indivisible unit of work</i> is successfully output, then the input is consumed by the below specified functions.
</p></div>

<div class="wording-numbered"><p>
The <i>narrow execution encoding</i> is the implementation-defined <code class="c-kw">LC_CTYPE</code> (7.11.1)-influenced locale execution environment encoding. The <i>wide execution encoding</i> is the implementation-defined <code class="c-kw">LC_CTYPE</code> (7.11.1)-influenced locale wide execution environment encoding. Functions which use <code class="c-kw">char</code> and <code class="c-kw">wchar_t</code>, or their qualified forms, derive their implementation-defined encoding from the locale. The other encodings are UTF-8, associated with <code class="c-kw">unsigned char</code>, UTF-16, associated with <code class="c-kw">char16_t</code>, and UTF-32, associated with <code class="c-kw">char32_t</code>.
</p></div>


<div class="wording-numbered"><p>
The types declared are <code class="c-kw">mbstate_t</code> (described in 7.29.1), <code class="c-kw">wchar_t</code> (described in 7.19), <code class="c-kw">char16_t</code> (described in 7.28), <code class="c-kw">char32_t</code> (described in 7.28), <code class="c-kw">size_t</code> (described in 7.19), and;

> ```c
> mchar_error
> ```

which is an enumerated type whose enumerators identify the status codes from a function call described below.
</p></div>

<div class="wording-numbered"><p>
The five macros declared are

> ```c
> STDC_C8_MAX
> STDC_C16_MAX
> STDC_C32_MAX
> STDC_MC_MAX
> STDC_MWC_MAX
> ```

which correspond to the maximum output for each single unit conversion function (7.S�.1) and its corresponding output type. Each macro shall expand into an integer constant expression with minimum values, as described in the following table.
</p></div>

<div class="wording-numbered">
<p>
There is an association of naming convention, types, meaning, and maximums, used to describe the functions in this clause:
</p>

<p>
<table>
	<tr>
		<th>Name</th>
		<th>Code Unit Type</th>
		<th>Meaning</th>
		<th>Maximum Output Macro</th>
		<th>Minimum Value</th>
	</tr>
	<tr>
		<td>mc</td>
		<td><code class="c-kw">char</code></td>
		<td>The <i>narrow execution encoding</i>,<br/>influenced by <code class="c-kw">LC_CTYPE</code></td>
		<td><code class="c-kw">STDC_MC_MAX</code></td>
		<td>`1`</td>
	</tr>
	<tr>
		<td>mwc</td>
		<td><code class="c-kw">wchar_t</code></td>
		<td>The <i>wide execution encoding</i>,<br/>influenced by <code class="c-kw">LC_CTYPE</code></td>
		<td><code class="c-kw">STDC_MWC_MAX</code></td>
		<td>`1`</td>
	</tr>
	<tr>
		<td>c8</td>
		<td><code class="c-kw">unsigned char</code></td>
		<td>UTF-8</td>
		<td><code class="c-kw">STDC_C8_MAX</code></td>
		<td>`4`</td>
	</tr>
	<tr>
		<td>c16</td>
		<td><code class="c-kw">char16_t</code></td>
		<td>UTF-16</td>
		<td><code class="c-kw">STDC_C16_MAX</code></td>
		<td>`2`</td>
	</tr>
	<tr>
		<td>c32</td>
		<td><code class="c-kw">char32_t</code></td>
		<td>UTF-32</td>
		<td><code class="c-kw">STDC_C32_MAX</code></td>
		<td>`1`</td>
	</tr>
</table>
</p>

<p>
The maximum output value specified in the above table is related to the single unit conversion functions (7.S�.1). These functions perform at most one indivisible unit of work, or return an error. The values shall be integer constant expressions large enough that conversions between each of the 5 encodings do not overflow a buffer of the maximum output size. The maximum output values do not affect the multi unit conversion functions (7.S�.2), which perform as many indivisible units of work as is possible until an error occurs.
</p>
</div>

<div class="wording-numbered"><p>
The enumerators of the enumerated type <code class="c-kw">mchar_error</code> are defined as follows:

> ```c
> mchar_error_ok                  =  0;
> mchar_error_invalid             = -1;
> mchar_error_incomplete_input    = -2;
> mchar_error_insufficient_output = -3;
> ```

Each value represents an error case when calling the relevant transcoding functions in &lt;stdmchar.h&gt;:

- For `mchar_error_insufficient_output`, when the input is correct and an indivisible unit of work can be performed but there is not enough output space;
- `mchar_error_incomplete_input`, when an incomplete input was found after exhausting the input'
- `mchar_error_invalid`, when an encoding error occurred; and,
- `mchar_error_ok`, when the operation was successful.

No other value shall be returned from the functions described in this clause.
</p></div>

<p><b>Recommended Practice</b></p>
<div class="wording-numbered"><p>
The maximum output macro values are intended for use in making automatic storage duration array declarations. Implementations should choose values for the macros that are spacious enough to accommodate a variety of underlying implementation choices for the target encodings supported by the narrow execution encodings and wide execution encodings, which in many cases can output more than one UTF-32 code point. Below is a set of values that can be resilient to future additions and changes:

> ```c
> #define STDC_C8_MAX  32
> #define STDC_C16_MAX 16
> #define STDC_C32_MAX  8
> #define STDC_MC_MAX  32
> #define STDC_MWC_MAX 16
> ```

</p></div>
</ins>
</div>
</blockquote>

<blockquote>
<div class="wording-section">
<ins>
<p><h5><b>7.S�.1 &emsp; Restartable and Non-Restartable Sized Single Unit Conversion Functions</b></h5></p>

> ```c
> #include <stdmchar.h>
> 
> mchar_error mcntomcn(const char** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error mcnrtowcn(const char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error mcntomwcn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error mcnrtomwcn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mcntoc8n(const char** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error mcnrtoc8n(const char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error mcntoc16n(const char** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error mcnrtoc16n(const char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mcntoc32n(const char** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error mcnrtoc32n(const char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error mwcntomcn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error mwcnrtomcn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcntomwcn(const wchar_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error mwcnrtomwcn(const wchar_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcntoc8n(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error mwcnrtoc8n(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcntoc16n(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error mwcnrtoc16n(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcntoc32n(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error mwcnrtoc32n(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error c8ntomcn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error c8nrtomcn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error c8ntomwcn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error c8nrtomwcn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c8ntoc8n(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error c8nrtoc8n(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error c8ntoc16n(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error c8nrtoc16n(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c8ntoc32n(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error c8nrtoc32n(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error c16ntomcn(const char16_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error c16nrtomcn(const char16_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error c16ntomwcn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error c16nrtomwcn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c16ntoc8n(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error c16nrtoc8n(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error c16ntoc16n(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error c16nrtoc16n(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c16ntoc32n(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error c16nrtoc32n(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error c32ntomcn(const char32_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error c32nrtomcn(const char32_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error c32ntomwcn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error c32nrtomwcn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c32ntoc8n(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error c32nrtoc8n(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error c32ntoc16n(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error c32nrtoc16n(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c32ntoc32n(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error c32nrtoc32n(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> ```

<div class="wording-numbered"><p>
Let:
<ul>
	<li><i>transcoding function</i> be one of the functions listed above transcribed in the form `mchar_error XntoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size)`;</li>
	<li><i>restartable transcoding function</i> be one of the functions listed above transcribed in the form `mchar_error XnrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state)`;</li>
	<li><i>X</i> and <i>Y</i> be one of the prefixes from the table from 7.S�;</li>
	<li><i>`charX`</i> and <i>`charY`</i> be the associated code unit types for <i>X</i> and <i>Y</i> from the table from 7.S�; and</li>
	<li><i>encoding X</i> and <i>encoding Y</i> be the associated encoding types for <i>X</i> and <i>Y</i> from the table from 7.S�.</li>
</ul>

The transcoding functions and restartable transcoding functions take an input buffer and an output buffer of the associated code unit types, potentially with their sizes. The function consumes any number of code units of type `charX` to perform a single indivisible unit of work necessary to convert some amount of input from encoding X to encoding Y, which results in zero or more output code units of type `charY`.
</p></div>

<p><b>Constraints</b></p>
<div class="wording-numbered"><p>

On success or failure, the transcoding functions and restartable transcoding functions shall return one of the above error codes (7.S�). `state` shall not be `NULL`. If `state` is not initialized to the initial conversion sequence for the function, or is used after being input into a function whose result was not one of `mchar_error_ok`, `mchar_error_insufficient_output`, or `mchar_error_incomplete_input`, then the behavior of the functions is unspecified. For the restartable transcoding functions, if `input` is `NULL`, then `*state` is set to the initial conversion sequence as described below and no other work is performed. Otherwise, for both restartable and non-restartable functions, `input` must not be `NULL`.
</p></div>

<p><b>Semantics</b></p>
<div class="wording-numbered"><p>
The restartable transcoding functions take the form:

> ```c
> mchar_error XnrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state);
> ```

They convert from code units of type `charX` interpreted according to encoding X to code units of type `charY` according to encoding Y given a conversion state of value `*state`. This function only performs a single indivisible unit of work. It does nothing and returns `mchar_error_ok` if the input is empty (only signified by `*input_size` is zero, if `input_size` is not `NULL`). The behavior of the restartable transcoding functions is as follows.

- If `input` is `NULL`, then `*state` is set to the initial conversion sequence associated with encoding X. The function returns `mchar_error_ok`.
- If `input_size` is not `NULL`, then the function reads code units from `*input` if `*input_size` is large enough to produce an indivisible unit of work. If no encoding errors have occurred but the input is exhausted before an indivisible unit of work can be computed, the function returns `mchar_error_incomplete_input`.
- If `input_size` is `NULL`, then `*input` is incremented and read as if it points to a buffer of sufficient size for a successful operation. The behavior is undefined if the supplied input is not large enough.
- If `output` is `NULL`, then no output will be written. `*input` is still read and incremented.
- If `output_size` is not `NULL`, then `*output_size` will be decremented the amount of code units that would have been written to `*output` (even if `output` was `NULL`). If the output is exhausted (`*output_size` will be decremented below zero), the function returns `mchar_error_insufficient_output`.
- If `output_size` is `NULL` and output is not `NULL`, then enough space is assumed in the buffer pointed to by `*output` for the entire operation. The behavior is undefined if the output buffer is not large enough.
</p></div>

<div class="wording-numbered"><p>
If the function returns `mchar_error_ok`, then all of the following is true:

- `*input` will be incremented by the number of code units read and successfully converted;
- if `input_size` is not `NULL`, `*input_size` is decremented by the number of code units read and successfully converted from the input;
- if `output` is not `NULL`, `*output` will be incremented by the number of code units written to the output; and,
- if `output_size` is not `NULL`, `*output_size` is decremented by the number of code units written to the output.

Otherwise, an error is returned is none of the above occurs. If the return value is `mchar_error_invalid`, then `*state` is in an unspecified state.
</p></div>

<div class="wording-numbered"><p>
The non-restartable transcoding functions take the form:

> ```c
> mchar_error XntoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size);
> ```

Let `XnrtoYn` be the <i>analogous restartable transcoding function</i>. The transcoding functions behave as-if they:

- create an automatic storage duration object of `mbstate_t` type called `temporary_state`,
- initialize `temporary_state` to the initial conversion sequence by calling the analogous restartable transcoding function with `NULL` for `input` and `&temporary_state`, as-if by invoking `XnrtoYn(NULL, NULL, NULL, NULL, &temporary_state)`;
- call the function and saves the result as-if by invoking `mchar_error err = XnrtoYn(input, input_size, output, output_size, &temporary_state);`; and,
- return `err`.

The interpretation of the values of the transcoding functions' parameters are identical meaning to the restartable transcoding functions' parameters.
</p></div>

<p><h5><b>7.S�.2 &emsp; Restartable and Non-Restartable Sized Multi Unit Conversion Functions</b></h5></p>

> ```c
> #include <stdmchar.h>
> 
> mchar_error mcsntomcsn(const char** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error mcsnrtomcsn(const char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error mcsntomwcsn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error mcsnrtomwcsn(const char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mcsntoc8sn(const char** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error mcsnrtoc8sn(const char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error mcsntoc16sn(const char** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error mcsnrtoc16sn(const char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mcsntoc32sn(const char** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error mcsnrtoc32sn(const char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error mwcsntomcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error mwcsnrtomcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcsntomwcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error mwcsnrtomwcsn(const wchar_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcsntoc8sn(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error mwcsnrtoc8sn(const wchar_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcsntoc16sn(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error mwcsnrtoc16sn(const wchar_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error mwcsntoc32sn(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error mwcsnrtoc32sn(const wchar_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error c8sntomwcsn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error c8snrtomwcsn(const unsigned char** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c8sntomcsn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error c8snrtomcsn(const unsigned char** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error c8sntoc8sn(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error c8snrtoc8sn(const unsigned char** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error c8sntoc16sn(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error c8snrtoc16sn(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c8sntoc32sn(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error c8snrtoc32sn(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error c16sntomwcsn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error c16snrtomwcsn(const char16_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c16sntomcsn(const char16_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error c16snrtomcsn(const char16_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error c16sntoc8sn(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error c16snrtoc8sn(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error c16sntoc16sn(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error c16snrtoc16sn(const char16_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c16sntoc32sn(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error c16snrtoc32sn(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mchar_error c32sntomcsn(const char32_t** input, size_t* input_size, char** output, size_t* output_size);
> mchar_error c32snrtomcsn(const char32_t** input, size_t* input_size, char** output, size_t* output_size, mbstate_t* state);
> mchar_error c32sntomwcsn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size);
> mchar_error c32snrtomwcsn(const char32_t** input, size_t* input_size, wchar_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c32sntoc8sn(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mchar_error c32snrtoc8sn(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mchar_error c32sntoc16sn(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mchar_error c32snrtoc16sn(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mchar_error c32sntoc32sn(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mchar_error c32snrtoc32sn(const char32_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> ```

<div class="wording-numbered"><p>
Let:
<ul>
	<li><i>transcoding function</i> be one of the functions listed above transcribed in the form `mchar_error XsntoYsn(const charX** input, size_t* input_size, const charY** output, size_t* output_size)`;</li>
	<li><i>restartable transcoding function</i> be one of the functions listed above transcribed in the form `mchar_error XnrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state)`;</li>
	<li><i>X</i> and <i>Y</i> be one of the prefixes from the table from 7.S�;</li>
	<li><i>`charX`</i> and <i>`charY`</i> be the associated code unit types for <i>X</i> and <i>Y</i> from the table from 7.S�; and</li>
	<li><i>encoding X</i> and <i>encoding Y</i> be the associated encoding types for <i>X</i> and <i>Y</i> from the table from 7.S�.</li>
</ul>

The transcoding functions and restartable transcoding functions take an input buffer and an output buffer of the associated code unit types, potentially with their sizes. The functions consume any number of code units to repeatedly perform a indivisible unit of work, which results in zero or more output code units. The functions will repeatedly perform an indivisible unit of work until either an error occurs or the input is exhausted.
</p></div>

<p><b>Constraints</b></p>
<div class="wording-numbered"><p>
On success or failure, the transcoding functions and restartable transcoding functions shall return one of the above error codes (7.S�). `state` shall not be `NULL`. If `state` is not initialized to the initial conversion sequence for the function, or is used after being input into a function whose result was not one of `mchar_error_ok`, `mchar_error_insufficient_output`, or `mchar_error_incomplete_input`, then the behavior of the functions is unspecified. For the restartable transcoding functions, if `input` is `NULL`, then `*state` is set to the initial conversion sequence as described below and no other work is performed. Otherwise, for both restartable and non-restartable functions, `input` must not be `NULL` and `input_size` must not be `NULL`.
</p></div>

<p><b>Semantics</b></p>
<div class="wording-numbered"><p>
The restartable transcoding functions take the form:

> ```c
> mchar_error XnsrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state);
> ```

It converts from code units of type `charX` interpreted according to encoding X to code units of type `charY` according to encoding Y given a conversion state of value `*state`. The behavior of these functions is as-if the analogous single unit function `XnrtoYn` was repeatedly called, with the same `input`, `input_size`, `output`, `output_size`, and `state` parameters, to perform multiple indivisible units of work. The function stops when an error occurs or the input is empty (only signified by `*input_size` is zero).
</p></div>

<div class="wording-numbered"><p>
Let <i>indivisible work</i> be defined as performing the following:

- If `input` is `NULL`, then `*state` is set to the initial conversion sequence associated with encoding X. The function returns `mchar_error_ok`.
- If `input_size` is not `NULL`, then the function reads code units from `*input` if `*input_size` is large enough to produce an indivisible unit of work. If no encoding errors have occurred but the input is exhausted before an indivisible unit of work can be computed, the function returns `mchar_error_incomplete_input`.
- If `input_size` is `NULL`, then `*input` is read that it points to a buffer of sufficient size and values. The behavior is undefined if the input buffer is not large enough.
- If `output` is `NULL`, then no output will be written.
- If `output_size` is not `NULL`, then `*output_size` will be decremented the amount of characters that would have been written to `*output` (even if `output` was `NULL`). If the output is exhausted (`*output_size` will be decremented below zero), the function returns `mchar_error_insufficient_output`.
- If `output_size` is `NULL` and output is not `NULL`, then enough space is assumed in the buffer pointed to by `*output` for the entire operation and the behavior is undefined if the output buffer is not large enough.

The behavior of the restartable transcoding functions is as follows.

- Evaluate indivisible work once.
- If the function has not yet returned and the input is not empty (`*input_size` is not zero), return to the first step.
- Otherwise, if the input is empty, return `mchar_error_ok`.
</p></div>

<div class="wording-numbered"><p>
The following is true after the invocation:

- `*input` will be incremented by the number of code units read and successfully converted. If `mchar_error_ok` is returned, then this will consume all the input. Otherwise, `*input` will point to the location just after the last successfully performed conversion.
- `*input_size` is decremented by the number of code units read from `*input` that were successfully converted. If no error occurred, then `*input_size` will be 0.
- if `output` is not `NULL`, `*output` will be incremented by the number of code units written.
- if `output_size` is not `NULL`, `*output_size` is decremented by the number of code units written to the output.

If the return value is `mchar_error_invalid`, then `*state` is in an unspecified state.
</p></div>

<div class="wording-numbered"><p>
The non-restartable transcoding functions take the form:

> ```c
> mchar_error XsntoYsn(const charX** input, size_t* input_size, const charY** output, size_t* output_size);
> ```

Let `XsnrtoYsn` be the <i>analogous restartable transcoding function</i>. The transcoding functions behave as-if they:

- create an automatic storage duration object of `mbstate_t` type called `temporary_state`,
- initialize `temporary_state` to the initial conversion sequence by calling the analogous restartable transcoding function with `NULL` for `input` and `&temporary_state`, as-if by invoking `XsnrtoYsn(NULL, NULL, NULL, NULL, &temporary_state)`;
- calls the analogous restartable transcoding function and saves the result as if by `mchar_error err = XsnrtoYsn(input, input_size, output, output_size, &temporary_state);`; and,
- returns `err`.

The values of the parameters contain identical meaning to the restartable form.
</p></div>
</ins>
</div>
</blockquote>




# Acknowledgements

Thank you to Philipp K. Krause for responding to the e-mails of a newcomer to matters of C and providing me with helpful guidance. Thank you to Rajan Bhakta, Daniel Plakosh, and David Keaton for guidance on how to submit these papers and get started in WG14. Thank you to Tom Honermann for lighting the passionate fire for proper text handling in me for not just C++, but for our sibling language C.

<div class="pagebreak"></div>




# Appendix {#appendix}

## (From revisions 0-3) What about UTF{X} ↔ UTF{Y} functions? {#appendix-proposed-utf}

Function interconverting between different Unicode Transformation Formats are not proposed here because -- while useful -- both sides of the encoding are statically known by the developer. The C Standard only wants to consider functionality strictly in the case where the implementation has more information / private information that the developer cannot access in a well-defined and standard manner. A developer can write their own Unicode Transformation Format conversion routines and get them completely right, whereas a developer cannot write the Wide Character and Multibyte Character functions without incredible heroics and/or error-prone assumptions.

This brings up an interesting point, however: if `__STD_C_UTF16__` and `__STD_C_UTF32__` both exist, does that not mean the implementation controls what `c16` and `c32` mean? This is true, **however**: within a (admittedly limited) survey of implementations, there has been no suggestion or report of an implementation which does not use UTF16 and UTF32 for their `char16_t` and `char32_t` literals, respectively. This motivation was, in fact, why a paper percolating through the WG21 Committee -- [p1041 "Make `char16_t`/`char32_t` literals be UTF16/UTF32"](https://wg21.link/p1041)[^P1041] -- was accepted. If this changes, then the conversion functions `c{X}toc{Y}` marked with an ❌ will become important.

Thankfully, that does not seem to be the case at this time. If such changes or such an implementation is demonstrated, these functions can be added to aid in portability.









# References

[^N2282]: Philip K. Krause. N2282: Additional multibyte/wide string conversion functions. June 2018. Published: [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2282.htm](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2282.htm).  
[^iconv]: Bruno Haible and Daiki Ueno. libiconv. August 2020. Published: [https://savannah.gnu.org/git/?group=libiconv](https://savannah.gnu.org/git/?group=libiconv).  
[^N2244]: WG14. Clarification Request Summary for C11, Version 1.13. October 2017. Published: [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2244.htm](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2244.htm).  
[^N1570]: ISO/IEC, WG14. Programming Languages - C (Committee Draft). April 12, 2011. Published: [http://www.open-std.org/jtc1/sc22/WG14/www/docs/n1570.pdf](http://www.open-std.org/jtc1/sc22/WG14/www/docs/n1570.pdf).  
[^P1041]: Robot Martinho Fernandes. p1041. February 2019. Published: [https://wg21.link/p1041](https://wg21.link/p1041).  
[^unicode_greater_detail]: JeanHeyd Meneide. Catching ⬆️: Unicode for C++ in Greater Detail". November 2019. Published Meeting C++: [https://www.youtube.com/watch?v=FQHofyOgQtM](https://www.youtube.com/watch?v=FQHofyOgQtM).
[^unicode_deep_c_diving]: JeanHeyd Meneide. Deep C Diving - Fast and Scalable Text Interfaces at the Bottom. July 2020. Published C++ On Sea: [https://youtu.be/X-FLGsa8LVc](https://www.youtube.com/watch?v=FQHofyOgQtM).
[^glibc-25744]: Tom Honermann and Carlos O'Donnell. `mbrtowc` with Big5-HKSCS returns 2 instead of 1 when consuming the second byte of certain double byte characters. [https://sourceware.org/bugzilla/show_bug.cgi?id=25744](https://sourceware.org/bugzilla/show_bug.cgi?id=25744)

<sub><sub><sub>May the Tower of Babel's curse be defeated.</sub></sub></sub>
