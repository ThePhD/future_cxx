---
title: Restartable and Non-Restartable Functions for Efficient Character Conversions | r2
layout: page
date: March 2nd, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis) \<<shepherd@soasis.org>\>
redirect_from:
  - /vendor/future_cxx/papers/source/nXXX1.html
  - /vendor/future_cxx/papers/source/n2431.html
  - /vendor/future_cxx/papers/source/n2440.html
  - /vendor/future_cxx/papers/source/n2500.html
  - /vendor/future_cxx/papers/source/C - Efficient CharacterConversions.html
hide: true
---

<style>
pre {
  margin-top: 0px;
  margin-bottom: 0px;
}
.ins, ins, ins *, span.ins, span.ins * {
  background-color: rgb(200, 250, 200);
  color: rgb(0, 136, 0);
  text-decoration: underline;
}
.del, del, del *, span.del, span.del * {
  background-color: rgb(250, 200, 200);
  color: rgb(255, 0, 0);
  text-decoration: line-through;
  text-decoration-color: rgb(255, 0, 0);
}
math, span.math {
  font-family: serif;
  font-style: italic;
}
ul {
  list-style-type: "— ";
}
blockquote {
  counter-reset: paragraph;
}
div.numbered, div.newnumbered {
  margin-left: 2em;
  margin-top: 1em;
  margin-bottom: 1em;
}
div.numbered:before, div.newnumbered:before {
  position: absolute;
  margin-left: -2em;
  display-style: block;
}
div.numbered:before {
  content: counter(paragraph);
  counter-increment: paragraph;
}
div.newnumbered:before {
  content: "�";
}
div.numbered ul, div.newnumbered ul {
  counter-reset: list_item;
}
div.numbered li, div.newnumbered li {
  margin-left: 3em;
}
div.numbered li:before, div.newnumbered li:before {
  position: absolute;
  margin-left: -4.8em;
  display-style: block;
}
div.numbered li:before {
  content: "(" counter(paragraph) "." counter(list_item) ")";
  counter-increment: list_item;
}
div.newnumbered li:before {
  content: "(�." counter(list_item) ")";
  counter-increment: list_item;
}

@media print
{
  .pagebreak { break-after: always }
}
</style>


_**Document**_: n2500  
_**Previous Revisions**_: n2440, n2431  
_**Audience**_: WG14  
_**Proposal Category**_: New Library Features  
_**Target Audience**_: General Developers, Text Processing Developers  
_**Latest Revision**_: [https://thephd.github.io/vendor/future_cxx/papers/source/n2440.html](https://thephd.github.io/vendor/future_cxx/papers/source/n2440.html)

<p style="text-align: center">
<span style="font-style: italic; font-weight: bold">Abstract:</span>
<p>Implementations firmly control what both the Wide Character and Multibyte Character literals are interpreted as for the encoding, as well as how they are treated at runtime by the Standard Library. While this control is fine, users of the Standard Library have no portability guarantees about how these library functions may behave, especially in the face of encodings that do not support each other's full codepage. And, despite additions to C11 for maybe-UTF16 and maybe-UTF32 encoded types, these functions only offer conversions of a single unit of information at a time, leaving orders of magnitude of performance on the table.</p>
<p>This paper proposes and explores additional library functionality to allow users to retrieve multibyte and wide character into a statically known encoding to enhance the ability to work with text.</p>
</p>



# Introduction and Motivation

C adopted conversion routines for the current active locale-derived/`LC_TYPE`-controlled/implementation-defined encoding for Multibyte (`mb`) Strings and Wide (`wc`) Strings. While the rationale for having such conversion routines to and from Multibyte and Wide strings in the C library are not explicitly stated in the documents, it is easy to derive the many benefits of a full ecosystem of both restarting (`r`) and non-restarting conversion routines for both single units and string-based bulk conversions for `mb` and `wc` strings. From ease of use with string literals to performance optimizations from bulk processing with vectorization and SIMD operations, the `mbs(r)towcs` — and vice-versa — granted a rich and fertile ground upon which C library developers took advantage of platform amenities, encoding specifics, and hardware support to provide useful and fast abstractions upon which encoding-aware applications could build.

Unfortunately, none of these API designs were granted to `char16_t` (`c16`) or `char32_t` (`c32`) conversion functions. Nor were they given a way to work with a well-defined 8-bit multibyte encoding such as UTF8 without having to first pin it down with platform-specific `setlocale(...)` calls. This has resulted in a series of extremely vexing problems when trying to write a portable, reliable C library code that is not locked to a specific vendor.

This paper looks at the problems, and then proposes a solution (without C Standard wording) with the goal of hoping to arrive at a solution that is worth implementing for the C Standard Library.


## Problem 1: Lack of Portability

Already, Windows, z/OS, and POSIX platforms greatly differ in what they offer for `char`-typed, Multibyte string encodings. EBCDIC is still in play after many decades. Windows's Active Code Page functionality on its machine prevents portability even within its own ecosystem. Platforms where LANG environment variables control functionality make communication between even processes on the same hardware a silent and often unforeseen gamble for library developers. Using functions which convert to/from `mbs` make it impossible to have stability guarantees not only between platforms, but for individual machines. Sometimes even cross-process communication becomes exceedingly problematic without opting into a serious amount of platform-specific or vendor-specific code and functionality to lock encodings in, harming the portability of C code greatly.

`wchar_t` does not fare better. By definition, a wide character type must be capable of holding the entire character set in a single unit of `wchar_t`. Reality, however, is different: this has been a fundamental impossibility for decades for implementers that switched to 16-bit UCS-2 early. IBM machines persist with this issue for all 32-bit builds, though some IBM platforms took advantage of the 64-bit change to do an ABI break and use UTF32 like other Linux distributions settled on. Even if one were to know this knowledge about IBM and program exclusively on their machines, certain IBM platforms can still end up in a situation where `wchar_t` is neither 32-bit UTF32 or 16-bit UCS-2/UTF16: the encoding can change to something else in certain Chinese locales, becoming completely different.

Windows is permanently stuck on having to explicitly detail that its implementation is "16-bit, UCS-2 as per the standard", before explicitly informing developers to use vendor-specific `WideCharToMultibyte`/`MultibyteToWideChar` to handle UTF16-encoded characters in `wchar_t`.

These solutions provide ways to achieve a local maxima for a specific vendor or platform. Unfortunately, this comes at the extreme cost of portability: the code has no guarantee it will work anywhere but your machine, and in a world that is increasingly interconnected by devices that interface with networks it makes sharing both data and code troublesome and hard to work with.


## Problem 2: What is the Encoding?

With `setlocale` and `getlocale` only responding to and returning implementation-defined `(const )char*`, there is no way to portably determine what the locale (and any associated encoding) should or should not be. The typical solution for this has been to code and program only for what is guaranteed by the Standard as what is in the Basic Character Set. While this works fine for source code itself, this produces an extremely hostile environment:

- conversion functions in the standard mangle and truncate data in (sometimes troubling, sometimes hilarious) fashion;
- programs which are not careful to meticulously track encoding of incoming text often lose the ability to understand that text;
- programmers can never trust the platform will support even the Latin characters in any representation of data beyond the 7th bit of a byte;
- and, interchange between cultures with different default encodings makes it impossible to communicate with others without entirely forsaking the standard library.

Abandoning the C __Standard__ Library -- to get __standard__ behavior across platforms -- is an exceedingly bitter pill to have to swallow as an enthusiastic C developer.


## Problem 3: Performance

The current version of the C Standard includes functions which attempt to alleviate Problems 1 and 2 by providing conversions from the per-process (and sometimes per-thread), locale-sensitive black box encoding of multibyte `char*` strings. They do this by providing conversions to `char16_t` units or `char32_t` units with `mbrtoc(16|32)` and `c(16|32)rtomb` functions. We will for a brief moment ignore the presence of the `__STD_C_UTF16__` and `__STD_C_UTF32__` macros and assume the two types mean that string literals and library functions convert to and from UTF16 and UTF32 respectively. We will also ignore that `wchar_t`'s encoding -- which is just as locale-sensitive and unknown at compile and runtime as `char`'s encoding is -- has no such conversion functions. These givens make it possible to say that we, as C programmers, have 2 known encodings which we can use to shepherd data into a stable state for manipulation and processing as library developers.

Even with that knowledge, these one-unit-at-a-time conversions functions are slower than they should be.

On many platforms, these one-at-a-time function calls come from the operating system, dynamically loaded libraries, or other places which otherwise inhibit compiler observation and optimizer inspection. Attempts to vectorize code or unroll loops built around these functions is thoroughly thwarted by this. Building static libraries or from source is very often a non-starter for many platforms. Since the encoding used for multibyte strings and wide strings are controlled by the implementation, it becomes increasingly difficult to provide the functionality to convert long segments of data with decent performance characteristics without needing to opt into vendor or platform specific tricks.


## Problem 4: wchar_t cannot roundtrip

With no `wctoc32` or `wctoc16` functions, the only way to convert a wide character or wide character string to a program-controlled, statically known encoding is to first invoke the wide character to multibyte function, and then invoke the multibyte function to either `char16_t` or `char32_t`.

This means that even if we have a well-behaved `wchar_t` that is not sensitive to the locale (e.g., on Windows machines), we lose data if the locale-controlled `char` encoding is not set to something that can handle all incoming code unit sequences. The locale-based encoding in a program can thus tank what is simply meant to be a pass-through encoding from `wchar_t` to `char16_t`/`char32_t`, all because the only Standards-compliant conversion channels data through the locale-based multibyte encoding `mb(s)(r)toX` functions.

For example, it was fundamentally impossible to engage in a successful conversion from `wchar_t` strings to `char` multibyte strings on Windows using the C Standard Library. Until a very recent Windows 10 update, UTF8 could **not** be set as the active system codepage either programmatically or through an experimental, deeply-buried setting. This has changed with Windows Version 1903 (May 2019 Update), but the problems do not stop there.

Because other library functions can be used to change or alter the locale in some manner, it once again becomes impossible to have a portable, compliant program with deterministic behavior if even one library changes the locale of the program, let alone if the encoding or locale is unexpected by the developer because they do not know of that culture or its locale setting. This hidden state is nearly impossible to account for, and ends up with software systems that cannot properly handle text in a meaningful way without abandoning C's encoding facilities, relying on vendor-specific extensions/encodings/tools, or confining one's program to only the 7-bit plane of existence.


## Motivation

In short, the problems C developers face today with respect to encoding and dealing with vendor and platform-specific black boxes is a staggering trifecta: non-portability between processes running on the same physical hardware, performance degradation from using standard facilities, and potentially having a locale changed out from under your program to prevent roundtripping.

This serves as the core motivation for this proposal.



# Prior Art

The Small Device C Compiler (SDCC) has already begun some of this work. One of its principle contributors, Philip K. Krause, wrote papers addressing exactly this problem[[1]](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2282.htm). Krause's work focuses entirely on non-restartable conversions from Multibyte Strings to `char16_t`. and `char32_t`. There is no need for a conversion to a UTF8 `char` style string for SDCC, since the Multibyte String in SDCC is always UTF8. This means that `mbstoc16s` and `mbstoc32s` and the "reverse direction" functions encompass an entire ecosystem of UTF8, UTF16, and UTF32.

While this is good for SDCC, this is not quite enough for other developers who attempt to write code in a cross-platform manner. While the non-restartable functions can save quite a bit of code size (see [[1]](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2282.htm)), unfortunately there are many encodings which are not as nice and require state to be processed correctly (e.g., Shift JIS and other ISO-2022 encodings). Not being able to retain that state between potential calls in a `mbstate_t` is detrimental to the ability to move forward with any encoding endeavor that wishes to bridge the gap between these disparate platform encodings and the current locale.

SDCC's work is still important, however: it demonstrates that these functions are implementable, even for small devices. With additional work being done to implement them for other platforms, there is strong evidence that this can be implemented in a cross-platform manner and thusly is suitable for the Standard Library.

<div class="pagebreak"></div>



# Proposed Changes

To understand what this paper proposes, an explanation of the current landscape is in order. The below table is meant to be read as being `{row}(r)to{column}`. The symbols provide the following information:

- ✔️: Function exists in both its restartable (function name has the indicative `r` in it) and non-restartable form.
- 🇷: Function exists only in its restartable form.
- ❌: Function does not exist at all.
- 🅿️: Modifying marker indicates intention to standardize either the restartable function (🇷) or both restartable and non-restartable functions (✔️).

Here is what exists in the C Standard Library so far:

<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{padding:10px 10px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg th{font-weight:normal;padding:10px 10px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg .tg-c3ow{border-color:inherit;text-align:center;vertical-align:top}
</style>
<table class="tg">
  <tr>
    <th class="tg-c3ow"></th>
    <th class="tg-c3ow">mb</th>
    <th class="tg-c3ow">wc</th>
    <th class="tg-c3ow">mbs</th>
    <th class="tg-c3ow">wcs</th>
    <th class="tg-c3ow">c8</th>
    <th class="tg-c3ow">c16</th>
    <th class="tg-c3ow">c32</th>
    <th class="tg-c3ow">c8s</th>
    <th class="tg-c3ow">c16s</th>
    <th class="tg-c3ow">c32s</th>
  </tr>
  <tr>
    <td class="tg-c3ow">mb</td>
    <td class="tg-c3ow"> ➖ </td>
    <td class="tg-c3ow"> ✔️ </td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"> ❌ </td>
    <td class="tg-c3ow"> 🇷 </td>
    <td class="tg-c3ow">🇷</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">wc</td>
    <td class="tg-c3ow">✔️</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"> ❌ </td>
    <td class="tg-c3ow"> ❌ </td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">mbs</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">✔️</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"> ❌ </td>
    <td class="tg-c3ow"> ❌ </td>
    <td class="tg-c3ow"> ❌ </td>
  </tr>
  <tr>
    <td class="tg-c3ow">wcs</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">✔️</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
  </tr>
  <tr>
    <td class="tg-c3ow">c8</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">c16</td>
    <td class="tg-c3ow">🇷</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">c32</td>
    <td class="tg-c3ow">🇷</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">c8s</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"> ❌ <br></td>
    <td class="tg-c3ow"> ❌ </td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
  </tr>
  <tr>
    <td class="tg-c3ow">c16s</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
  </tr>
  <tr>
    <td class="tg-c3ow">c32s</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
  </tr>
</table>

<div class="pagebreak"></div>

To support getting data losslessly out of `wchar_t` and `char` strings controlled firmly by the implementation -- and back into those types if the code units in the characters are supported --, the following functionality is proposed:

<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{padding:10px 10px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg th{padding:10px 10px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg .tg-c3ow{border-color:inherit;text-align:center;vertical-align:top}
.tg .tg-3ib7{border-color:inherit;text-align:center;vertical-align:top}
</style>
<table class="tg">
  <tr>
    <th class="tg-3ib7"></th>
    <th class="tg-c3ow">mb</th>
    <th class="tg-c3ow">wc</th>
    <th class="tg-c3ow">mbs</th>
    <th class="tg-c3ow">wcs</th>
    <th class="tg-c3ow">c8</th>
    <th class="tg-c3ow">c16</th>
    <th class="tg-c3ow">c32</th>
    <th class="tg-c3ow">c8s</th>
    <th class="tg-c3ow">c16s</th>
    <th class="tg-c3ow">c32s</th>
  </tr>
  <tr>
    <td class="tg-c3ow">mb</td>
    <td class="tg-c3ow"> ➖ </td>
    <td class="tg-c3ow"> ✔️ </td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow"> 🇷 </td>
    <td class="tg-c3ow">🇷</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">wc</td>
    <td class="tg-c3ow">✔️</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">mbs</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">✔️</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
  </tr>
  <tr>
    <td class="tg-c3ow">wcs</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">✔️</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
  </tr>
  <tr>
    <td class="tg-c3ow">c8</td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">c16</td>
    <td class="tg-c3ow">🇷</td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">c32</td>
    <td class="tg-c3ow">🇷</td>
    <td class="tg-c3ow">🅿️🇷</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
  </tr>
  <tr>
    <td class="tg-c3ow">c8s</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
  </tr>
  <tr>
    <td class="tg-c3ow">c16s</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
    <td class="tg-c3ow">❌</td>
  </tr>
  <tr>
    <td class="tg-c3ow">c32s</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow">🅿️✔</td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow"></td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">❌</td>
    <td class="tg-c3ow">➖</td>
  </tr>
</table>

In particular, it is imperative to recognize that the implementation is the "sole proprietor" of the wide character (`wc`) and Multibyte (`mb`) encodings for its string literals (compiler) and library functions (standard library).


## Single-Unit Functions

Focus should be applied on adding the one-at-a-time functions for `char` and `wchar_t`, which begets the start of this proposal:

- Multibyte Character:
  - `mbrtoc8` and `c8rtomb`
- Wide Character:
  - `wcrtoc8` and `c8rtowc`
  - `wcrtoc16` and `c16rtowc`
  - `wcrtoc32` and `c32rtowc`

Only the "`r`" (restarting) versions of these functions are proposed here because otherwise single code unit conversions would not be able to respect multiple code units of either `char16_t` or `char32_t`. For more information about multi-unit encodings and the trouble that comes with not using a restartable version and not returning sufficient information, see the discussion related to [N1991 and DR488](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2244.htm#dr_488)[[2]](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2244.htm#dr_488).

The forms of such functions would be as follows:

```cpp
/* Multibyte Character, Single Unit (UTF8): */
size_t mbrtoc8(char* restrict pc8, const char* restrict src, size_t src_len, mbstate_t* restrict state);
size_t c8rtomb(char* restrict pc, const char* restrict src, size_t src_len, mbstate_t* restrict state);

/* Wide Character, Single Unit: */
size_t wcrtocX(charX_t* restrict pcX, const wchar_t* restrict src, size_t src_len, mbstate_t* restrict state);
size_t cXrtowc(wchar_t* restrict pwc, const charX_t* restrict src, size_t src_len, mbstate_t* restrict state);
```

where `X` and `charX_t` is one of { `8`, `char` }, { `16`, `char16_t` }, or { `32`, `char32_t` } for the function's specification.


## Multi-Unit Functions

Additionally, the following is also proposed:

- Multibyte Character Strings:
  - `mbstoc8s` and `c8stombs`
  - `mbsrtoc8s` and `c8srtombs`
  - `mbstoc16s` and `c16stombs`
  - `mbsrtoc16s` and `c16srtombs`
  - `mbstoc32s` and `c32stombs`
  - `mbsrtoc32s` and `c32srtombs`

- Wide Character Strings:
  - `wcstoc8s` and `c8stowcs`
  - `wcsrtoc8s` and `c8srtowcs`
  - `wcstoc16s` and `c16stowcs`
  - `wcsrtoc16s` and `c16srtowcs`
  - `wcstoc32s` and `c32stowcs`
  - `wcsrtoc32s` and `c32srtowcs`

The functions follow the same conventions as their counterparts, `mbstowcs` and `wcstombs` (or `mbsrtowcs` and `wcsrtombs`, for the restartable versions). These allow for the implementation to bulk-convert to and from a statically-known encoding. Bulk conversions has significant performance benefits in both C and C++ code: see [[4]](https://hsivonen.fi/encoding_rs/#results) and [[5]](https://www.youtube.com/watch?v=5FQ87-Ecb-A) (both authors have shown that their code can be ported to use a C interface or just be written directly in C itself).

The forms of such functions would be as follows:

```cpp
/* Multibyte Character Strings: */
size_t mbstocXs(charX_t* restrict dest, const char* restrict src, size_t dest_len);
size_t cXstombs(char* restrict dest, const charX_t* restrict src, size_t dest_len);
size_t mbsrtocXs(charX_t* restrict dest, const char** restrict src, size_t dest_len, mbstate_t* restrict state);
size_t cXsrtombs(char* dest, const charX_t** restrict src, size_t dest_len, mbstate_t* restrict state);

/* Wide Character Strings: */
size_t wcstocXs(charX_t* restrict dest, const wchar_t* restrict src, size_t dest_len);
size_t cXstowcs(wchar_t* restrict dest, const charX_t* restrict src, size_t dest_len);
size_t wcsrtocXs(charX_t* restrict dest, const wchar_t** restrict src, size_t dest_len, mbstate_t* state);
size_t cXsrtowcs(wchar_t* restrict dest, const charX_t** restrict src, size_t dest_len, mbstate_t* restrict state);
```

where `X` and `charX_t` is one of { `8`, `char` }, { `16`, `char16_t` }, or { `32`, `char32_t` } for the function's specification.


## Sized Conversion Functions

Following the conventions of the string-based conversion functions already present, the above functions will use null termination as a marker for stopping. Many streams of text data today have embedded nulls in them, and have thusly required many creative solutions for avoiding embedded nulls (including encodings like Modified UTF-8 (MUTF8)). Thusly, as an extension for this proposal targeting the Standard Library, sized versions of the above functions which take a `size_t` are also proposed. This parameter would specify the number of code units in the source string.

Previously, sized functions for certain string operations were attempted by trying to duplicate current library functionality but with an `RSIZE_MAX`-respecting parameter introduced the C 11 Standard, Annex K (for functions like `strncpy_s`). While the intention and rationale (N1570, §K.3.2 in [[3]](http://www.open-std.org/jtc1/sc22/WG14/www/docs/n1570.pdf)) made it explicitly clear the goal was to prevent potential size errors when going from a signed number to `size_t` and promote safety, the effect of such changes was different. `RSIZE_MAX` values on certain platforms were restrictively tiny, taking payloads of reasonable sizes but still rejecting them. C programmers used to developing on certain platforms would use these functions in one area, port that code to another platform, and then would experience what amounted to a Denial of Service as their payloads exceeded the restrictively small `RSIZE_MAX` values.

Given Annex K's history and issues, this paper does not propose to implement anything like the `rsize` functions. Instead, this paper would like to promote `size_t`-sized function for all of the above currently existing (✔️) and desired (🅿️) functions in the above table. Particularly:

- Multibyte Character Strings:
  - `mbsntoc8s` and `c8sntombs`
  - `mbsnrtoc8s` and `c8snrtombs`
  - `mbsntoc16s` and `c16sntombs`
  - `mbsnrtoc16s` and `c16snrtombs`
  - `mbsntoc32s` and `c32sntombs`
  - `mbsnrtoc32s` and `c32snrtombs`

- Wide Character Strings:
  - `wcsntoc8s` and `c8sntowcs`
  - `wcsnrtoc8s` and `c8snrtowcs`
  - `wcsntoc16s` and `c16sntowcs`
  - `wcsnrtoc16s` and `c16snrtowcs`
  - `wcsntoc32s` and `c32sntowcs`
  - `wcsnrtoc32s` and `c32snrtowcs`

The forms of such functions would be as follows:

```cpp
/* Multibyte Character Strings: */
size_t mbsntocXs(size_t dest_len, charX_t* restrict dest, size_t src_len, const char* restrict src);
size_t cXsntombs(size_t dest_len, char* restrict dest, size_t src_len, const charX_t* restrict src);
size_t mbsnrtocXs(size_t dest_len, charX_t* restrict dest, size_t src_len, const char** restrict src, mbstate_t* restrict state);
size_t cXsnrtombs(size_t dest_len, char* restrict dest, size_t src_len, const charX_t** restrict src, mbstate_t* restrict state);

/* Wide Character Strings: */
size_t wcsntocXs(size_t dest_len, charX_t* restrict dest, const wchar_t* restrict src);
size_t cXsntowcs(size_t dest_len, wchar_t* restrict dest, const charX_t* restrict src);
size_t wcsnrtocXs(size_t dest_len, charX_t* restrict dest, size_t src_len, const wchar_t** restrict src, mbstate_t* restrict state);
size_t cXsnrtowcs(size_t dest_len, wchar_t* restrict dest, size_t src_len, const charX_t** restrict src, mbstate_t* restrict state);
```

where `X` and `charX_t` is one of { `8`, `char` }, { `16`, `char16_t` }, or { `32`, `char32_t` } for the function’s specification. Similar additions can be made for the currently existing `mbs(r)towcs` and `wcs(r)tombs` functions as well.


## What about UTF{X} 🔄 UTF{Y} functions?

Function interconverting between different Unicode Transformation Formats are not proposed here because -- while useful -- both sides of the encoding are statically known by the developer. The C Standard only wants to consider functionality strictly in the case where the implementation has more information / private information that the developer cannot access in a well-defined and standard manner. A developer can write their own Unicode Transformation Format conversion routines and get them completely right, whereas a developer cannot write the Wide Character and Multibyte Character functions without incredible heroics and/or error-prone assumptions.

This brings up an interesting point, however: if `__STD_C_UTF16__` and `__STD_C_UTF32__` both exist, does that not mean the implementation controls what `c16` and `c32` mean? This is true, **however**: within a (admittedly limited) survey of implementations, there has been no suggestion or report of an implementation which does not use UTF16 and UTF32 for their `char16_t` and `char32_t` literals, respectively. This motivation was, in fact, why a paper percolating through the WG21 Committee -- [p1041 "Make `char16_t`/`char32_t` literals be UTF16/UTF32"[6]](https://wg21.link/p1041) -- was accepted. If this changes, then the conversion functions `c{X}toc{Y}` marked with an ❌ will become important.

Thankfully, that does not seem to be the case at this time. If such changes or such an implementation is demonstrated, these functions can be added to what should be added.


# Wording

Conspicuously, you will notice that the below wording is missing the `c8` functions from the above listing. This is because Tom Honermann has made it clear he would like to get `char8_t` into the C Language to maintain parity with C++ and its changes. Seeing as there is already a `u8` character literal type, it is prudent to hold off on giving direct wording to specify any interfaces which may be better served with `char8_t`, especially as such conversions intend to work explicitly with UTF-8.

## Intent

The intent of these changes is to add the following 4 character functions.

- Add `wcrtoc16`, `c16rtowc` functions (restartable, c16, wide, null-terminated)
- Add `wcrtoc32`, `c32rtowc` functions (restartable, c32, wide, null-terminated)

The character functions already existing and presented above will serve as the basis for the following 32 string functions:

- Add `mbstoc16s`, `c16stombs` functions (non-restartable, char16_t, multi byte, null-terminated)
- Add `mbsrtoc16s`, `c16srtombs` functions (restartable, char16_t, multi byte, null-terminated)
- Add `mbsntoc16s`, `c16sntombs` functions (non-restartable, char16_t, multi byte, sized)
- Add `mbsnrtoc16s`, `c16snrtombs` functions (restartable, char16_t, multi byte, sized)
- Add `mbstoc32s`, `c32stombs` functions (non-restartable, char32_t, multi byte, null-terminated)
- Add `mbsrtoc32s`, `c32srtombs` functions (restartable, char32_t, multi byte, null-terminated)
- Add `mbsntoc32s`, `c32sntombs` functions (non-restartable, char32_t, multi byte, sized)
- Add `mbsnrtoc32s`, `c32snrtombs` functions (restartable, char32_t, multi byte, sized)
- Add `wcstoc16s`, `c16stowcs` functions (non-restartable, char16_t, wide, null-terminated)
- Add `wcsrtoc16s`, `c16srtowcs` functions (restartable, char16_t, wide, null-terminated)
- Add `wcsntoc16s`, `c16sntowcs` functions (non-restartable, char16_t, wide, sized)
- Add `wcsnrtoc16s`, `c16snrtowcs` functions (restartable, char16_t, wide, sized)

There is no wording for `c8`-style functions due to waiting for a proper decision regarding `char8_t` from Tom Honermann's paper.



## Library Wording

Add to §7.28.1 "Restartable multibyte/wide character conversion functions" new subsections for the `wcrtoc16`, `c16rtowc`, `wcrtoc32`, and `c32rtowc` functions:

> <p><ins><b>7.28.1.� The <code>wcrtoc16</code> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <sup>1</sup> 
> ```cpp
> #include <uchar.h>
> size_t wcrtoc16(char16_t * restrict pc16, wchar_t * restrict s, size_t n, mbstate_t * ps);
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> If <code>s</code> is a null pointer, the <b><code>wcrtoc16</code></b> function is equivalent to the call:</ins></p>
> ```cpp
> wcrtoc16(NULL, L"", 1, ps)
> ```
> 
> <p><ins>In this case, the values of the parameters <code>pc16</code> and <code>n</code> are ignored.</ins></p>
> 
> <p><ins><sup>3</sup> If <code>s</code> is not a null pointer, the <b><code>wcrtoc16</code></b> function inspects at most <code>n</code> elements pointed to by <code>s</code> to determine the number of elements needed to complete the next wide character (including any shift sequences). If the function determines the next wide character is complete and valid, it determines the values of the corresponding <code>char16_t</code> characters and then, if <code>pc16</code> is not a null pointer, stores the value of the first (or only) such character in the object pointer to by <code>pc16</code>. Subsequent calls will store successive <code>char16_t</code> characters without consuming additional input until all the <code>char16_t</code> characters have been stored. If the corresponding <code>char16_t</code> character is the null character, the resulting state described is the initial conversion state.</ins></p>
> 
> <p><ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> The <b><code>wcrtoc16</code></b> function returns the first of the following that applies (given the current conversion state):</ins></p>
> <dl>
> <ins><dt><code>0</code></dt> <dd>if the next <code>n</code> or fewer elements complete the wide character that corresponds to the null <code>char16_t</code> character (which is the value stored).</dd></ins>
> 
> <ins><dt><i>between</i> <code>1</code> <i>and</i> <code>n</code> <i>inclusive</i></dt> <dd>if the next <code>n</code> or fewer elements complete a valid wide character (which is the value stored); the value returned is the number of elements that complete the wide character.</dd></ins>
> 
> <ins><dt><code>(size_t)(-3)</code></dt> <dd>if the next <code>char16_t</code> character resulting from a previous call has been stored (no wide characters from the input have been consumed by this call).</dd></ins>
> 
> <ins><dt><code>(size_t)(-2)</code></dt> <dd>if the next <code>n</code> or fewer elements contribute to an incomplete (but potentially valid) <code>char16_t</code> character, and all <code>n</code> elements have been processed (no value is stored).</dd></ins>
> 
> <ins><dt><code>(size_t)(-1)</code></dt> <dd>if an encoding error occurs, in which case the next <code>n</code> or fewer elements do not contribute to complete or valid <code>char16_t</code> characters: the function stores the value of the macro <code><b>EILSEQ</b></code> in <code><b>errno</b></code>.</dd></ins>
> </dl>

> <p><ins><b>7.28.1.� The <code>c16rtowc</code> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <ins><sup>1</sup></ins>
> ```cpp
> #include <uchar.h>
> size_t c16rtowc(wchar_t * restrict pwc, char16_t * restrict s, size_t n, mbstate_t * restrict ps);
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> If <code>s</code> is a null pointer, the <b><code>c16rtowc</code></b> function is equivalent to the call:</ins></p>
> ```cpp
> c16rtowc(NULL, u"", 1, ps)
> ```
> 
> <p><ins>In this case, the values of the parameters <code>pwc</code> and <code>n</code> are ignored.</ins></p>
> 
> <p><ins><sup>3</sup> If <code>s</code> is not a null pointer, the <b><code>c16rtowc</code></b> function inspects at most <code>n</code> elements pointed to by <code>s</code> to determine the number of elements needed to complete the next <code>char16_t</code> character (including any shift sequences). If the function determines the next <code>char16_t</code> character is complete and valid, it determines the values of the corresponding wide characters and then, if <code>pwc</code> is not a null pointer, stores the value of the first (or only) such character in the object pointer to by <code>pwc</code>. Subsequent calls will store successive wide characters without consuming additional input until all the wide characters have been stored. If the corresponding wide character is the null character, the resulting state described is the initial conversion state.</ins></p>
> 
> <p><ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> The <b><code>c16rtowc</code></b> function returns the first of the following (including conversion state):
> <dl>
> <ins><dt><code>0</code></dt> <dd>if the next <code>n</code> or fewer elements complete the <code>char16_t</code> character that corresponds to the null wide character (which is the value stored).</dd></ins>
> 
> <ins><dt><i>between</i> <code>1</code> <i>and</i> <code>n</code> <i>inclusive</i></dt> <dd>if the next <code>n</code> or fewer elements complete a valid <code>char16_t</code> character (which is the value stored); the value returned is the number of elements that complete the <code>char16_t</code> character.</dd></ins>
> 
> <ins><dt><code>(size_t)(-3)</code></dt> <dd>if the next wide character resulting from a previous call has been stored (no <code>char16_t</code> characters from the input have been consumed by this call).</dd></ins>
> 
> <ins><dt><code>(size_t)(-2)</code></dt> <dd>if the next <code>n</code> or fewer elements contribute to an incomplete (but potentially valid) wide character, and all <code>n</code> elements have been processed (no value is stored).</dd></ins>
> 
> <ins><dt><code>(size_t)(-1)</code></dt> <dd>if an encoding error occurs, in which case the next <code>n</code> or fewer elements do not contribute to complete or valid wide characters: the function stores the value of the macro <code><b>EILSEQ</b></code> in <code><b>errno</b></code>.</dd></ins>
> </dl>

> <p><ins><b>7.28.1.� The <code>wcrtoc32</code> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <ins><sup>1</sup></ins>
> ```cpp
> #include <uchar.h>
> size_t wcrtoc32(char32_t * restrict pc32, wchar_t * restrict s, size_t n, mbstate_t * ps);
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> If <code>s</code> is a null pointer, the <b><code>wcrtoc32</code></b> function is equivalent to the call:</ins></p>
> ```cpp
> wcrtoc32(NULL, L"", 1, ps)
> ```
> 
> <p><ins>In this case, the values of the parameters <code>pc32</code> and <code>n</code> are ignored.</ins></p>
> 
> <p><ins><sup>3</sup> If <code>s</code> is not a null pointer, the <b><code>wcrtoc32</code></b> function inspects at most <code>n</code> elements pointed to by <code>s</code> to determine the number of elements needed to complete the next wide character (including any shift sequences). If the function determines the next wide character is complete and valid, it determines the values of the corresponding <code>char32_t</code> characters and then, if <code>pc32</code> is not a null pointer, stores the value of the first (or only) such character in the object pointer to by <code>pc32</code>. Subsequent calls will store successive <code>char32_t</code> characters without consuming additional input until all the <code>char32_t</code> characters have been stored. If the corresponding <code>char32_t</code> character is the null character, the resulting state described is the initial conversion state.</ins></p>
> 
> <p><ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> The <b><code>wcrtoc32</code></b> function returns the first of the following that applies (given the current conversion state):</ins></p>
> <dl>
> <ins><dt><code>0</code></dt> <dd>if the next <code>n</code> or fewer elements complete the wide character that corresponds to the null <code>char32_t</code> character (which is the value stored).</dd></ins>
> 
> <ins><dt><i>between</i> <code>1</code> <i>and</i> <code>n</code> <i>inclusive</i></dt> <dd>if the next <code>n</code> or fewer elements complete a valid wide character (which is the value stored); the value returned is the number of elements that complete the wide character.</dd></ins>
> 
> <ins><dt><code>(size_t)(-3)</code></dt> <dd>if the next <code>char32_t</code> character resulting from a previous call has been stored (no wide characters from the input have been consumed by this call).</dd></ins>
> 
> <ins><dt><code>(size_t)(-2)</code></dt> <dd>if the next <code>n</code> or fewer elements contribute to an incomplete (but potentially valid) <code>char32_t</code> character, and all <code>n</code> elements have been processed (no value is stored).</dd></ins>
> 
> <ins><dt><code>(size_t)(-1)</code></dt> <dd>if an encoding error occurs, in which case the next <code>n</code> or fewer elements do not contribute to complete or valid <code>char32_t</code> characters: the function stores the value of the macro <code><b>EILSEQ</b></code> in <code><b>errno</b></code>.</dd></ins>
> </dl>

> <p><ins><b>7.28.1.� The <code>c32rtowc</code> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <ins><sup>1</sup></ins>
> ```cpp
> #include <uchar.h>
> size_t c32rtowc(wchar_t * restrict pwc, char32_t * restrict s, size_t n, mbstate_t * restrict ps);
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> If <code>s</code> is a null pointer, the <b><code>c32rtowc</code></b> function is equivalent to the call:</ins></p>
> ```cpp
> c32rtowc(NULL, u"", 1, ps)
> ```
> 
> <p><ins>In this case, the values of the parameters <code>pwc</code> and <code>n</code> are ignored.</ins></p>
> 
> <p><ins><sup>3</sup> If <code>s</code> is not a null pointer, the <b><code>c32rtowc</code></b> function inspects at most <code>n</code> elements pointed to by <code>s</code> to determine the number of elements needed to complete the next <code>char32_t</code> character (including any shift sequences). If the function determines the next <code>char32_t</code> character is complete and valid, it determines the values of the corresponding wide characters and then, if <code>pwc</code> is not a null pointer, stores the value of the first (or only) such character in the object pointer to by <code>pwc</code>. Subsequent calls will store successive wide characters without consuming additional input until all the wide characters have been stored. If the corresponding wide character is the null character, the resulting state described is the initial conversion state.</ins></p>
> 
> <p><ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> The <b><code>c32rtowc</code></b> function returns the first of the following (including conversion state):
> <dl>
> <ins><dt><code>0</code></dt> <dd>if the next <code>n</code> or fewer elements complete the <code>char32_t</code> character that corresponds to the null wide character (which is the value stored).</dd></ins>
> 
> <ins><dt><i>between</i> <code>1</code> <i>and</i> <code>n</code> <i>inclusive</i></dt> <dd>if the next <code>n</code> or fewer elements complete a valid <code>char32_t</code> character (which is the value stored); the value returned is the number of elements that complete the <code>char32_t</code> character.</dd></ins>
> 
> <ins><dt><code>(size_t)(-3)</code></dt> <dd>if the next wide character resulting from a previous call has been stored (no <code>char32_t</code> characters from the input have been consumed by this call).</dd></ins>
> 
> <ins><dt><code>(size_t)(-2)</code></dt> <dd>if the next <code>n</code> or fewer elements contribute to an incomplete (but potentially valid) wide character, and all <code>n</code> elements have been processed (no value is stored).</dd></ins>
> 
> <ins><dt><code>(size_t)(-1)</code></dt> <dd>if an encoding error occurs, in which case the next <code>n</code> or fewer elements do not contribute to complete or valid wide characters: the function stores the value of the macro <code><b>EILSEQ</b></code> in <code><b>errno</b></code>.</dd></ins>
> </dl>


Add a new section §7.28.2 "Non-restartable multibyte/wide string conversion functions":

> <p><ins><h6>7.28.2 Non-restartable multibyte/wide string conversion functions</h6></ins></p>
> 
> <p><ins><b>7.28.2.1 The <b><code>mbstoc16s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbstoc16s(char16_t *restrict c16s, const char *restrict s, size_t n)
> ```
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>mbstoc16s</code></b> function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by s into a sequence of corresponding <code>char16_t</code> characters and stores not more than <code>n</code> <code>char16_t</code> characters into the array pointed to by <code>c16s</code>.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <b><code>mbrtoc16</code></b> function with a non-null <code>ps</code> and <b><code>MB_MAX_LEN</code></b> for <code>n</code>. However, no multibyte characters that follow a null character (which is converted into a null <code>char16_t</code> character) will be examined or converted.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a multibyte character is encountered that does not correspond to a valid sequence of <code>char16_t</code> characters, the <b><b><code>mbstoc16s</code></b></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><b><code>mbstoc16s</code></b></b> function returns the number of array elements modified, not including a terminating null <code>char16_t</code> character, if any.</ins></p>

> <p><ins><b>7.28.2.2 The <b><code>c16stombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c16stombs(char *restrict s, const char16_t *restrict c16s, size_t n)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c16stombs</code></b> function converts a sequence of <code>char16_t</code> characters from the array pointed to by c16s into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if a null character is stored.</ins></p>
> 
> <p><ins><sup>3</sup> Each sequence of <code>char16_t</code> characters is converted as if by calls to the c16rtomb function with a non-null <code>ps</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a sequence of <code>char16_t</code> characters is encountered that does not correspond to a valid multibyte character, the c16stombs function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c16stombs</code></b> function returns the number of bytes modified, not including a terminating null character, if any.</ins></p>

> <p><ins><b>7.28.2.3 The <b><code>mbstoc32s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbstoc32s(char32_t *restrict c32s, const char *restrict s, size_t n)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The mbstoc32s function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char32_t</code> characters and stores not more than <code>n</code> <code>char32_t</code> characters into the array pointed to by <code>c32s</code>.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <code>mbrtoc32</code> function with a non-null <code>ps</code> and <code>MB_MAX_LEN</code> for <code>n</code>. However, no multibyte characters that follow a null character (which is converted into a null <code>char32_t</code> character) will be examined or converted.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If an invalid multibyte character is encountered, the <b><code>mbstoc32s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>mbstoc32s</code></b> function returns the number of array elements modified, not including a terminating null <code>char32_t</code> character, if any.</ins></p>

> <p><ins><b>7.28.2.4 The <b><code>c32stombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c32stombs(char *restrict s, const char32_t *restrict s, size_t n)>
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c32stombs</code></b> function converts a sequence of <code>char32_t</code> characters from the array pointed to by c32s into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if a null character is stored.</ins></p>
> 
> <p><ins><sup>3</sup>Each <code>char32_t</code> character is converted as if by calls to the <code>c32rtomb</code> function with a non-null <code>ps</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a <code>char32_t</code> character is encountered that does not correspond to a valid multibyte character, the <b><code>c32stombs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c32stombs</code></b> function returns the number of bytes modified, not including a terminating null character, if any.</ins></p>

> <p><ins><b>7.28.2.5 The <b><code>mbsntoc16s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbsntoc16s(size_t c16n, char16_t *restrict c16s, size_t n, const char *restrict s)
> ```
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>mbsntoc16s</code></b> function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char16_t</code> characters and stores not more than <code>c16n</code> <code>char16_t</code> characters into the array pointed to by <code>c16s</code>. It does not convert more than <code>n</code> multibyte characters.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <b><code>mbrtoc16</code></b> function with a non-null <code>ps</code> and <b><code>MB_MAX_LEN</code></b> for <code>n</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a multibyte character is encountered that does not correspond to a valid sequence of <code>char16_t</code> characters, the <b><b><code>mbsntoc16s</code></b></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><b><code>mbsntoc16s</code></b></b> function returns the number of array elements modified.</ins></p>

> <p><ins><b>7.28.2.6 The <b><code>c16sntombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c16sntombs(size_t n, char *restrict s, size_t c16n, const char16_t *restrict c16s)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c16sntombs</code></b> function converts a sequence of <code>char16_t</code> characters from the array pointed to by <code>c16s</code> into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if the limit of <code>c16n</code> elements is converted.</ins></p>
> 
> <p><ins><sup>3</sup> Each sequence of <code>char16_t</code> characters is converted as if by calls to the <code>c16rtomb</code> function with a non-null <code>ps</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a sequence of <code>char16_t</code> characters is encountered that does not correspond to a valid multibyte character, the <b><code>c16sntombs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c16sntombs</code></b> function returns the number of bytes modified.</ins></p>

> <p><ins><b>7.28.2.7 The <b><code>mbsntoc32s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbsntoc32s(size_t c32n, char32_t *restrict c32s, size_t n, const char *restrict s)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>mbsntoc32s</code></b> function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char32_t</code> characters and stores not more than <code>c32n</code> <code>char32_t</code> characters into the array pointed to by <code>c32s</code>. It does not convert more than <code>n</code> multibyte characters.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <code>mbrtoc32</code> function with a non-null <code>ps</code> and <code>MB_MAX_LEN</code> for <code>n</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If an invalid multibyte character is encountered, the <b><code>mbsntoc32s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>mbsntoc32s</code></b> function returns the number of array elements modified.

> <p><ins><b>7.28.2.8 The <b><code>c32sntombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c32sntombs(size_t n, char *restrict s, size_t c32n, const char32_t *restrict c32s)>
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c32sntombs</code></b> function converts a sequence of <code>char32_t</code> characters from the array pointed to by c32s into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if the limit of <code>c32n</code> elements is converted.</ins></p>
> 
> <p><ins><sup>3</sup>Each <code>char32_t</code> character is converted as if by calls to the <code>c32rtomb</code> function with a non-null <code>ps</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a <code>char32_t</code> character is encountered that does not correspond to a valid multibyte character, the <b><code>c32sntombs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c32sntombs</code></b> function returns the number of bytes modified.</ins></p>

Add a new section §7.28.3 "Restartable multibyte/wide string conversion functions":

> <p><ins><h6>7.28.3 Restartable multibyte/wide string conversion functions</h6></ins></p>
> 
> <p><ins><b>7.28.3.1 The <b><code>mbsrtoc16s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbsrtoc16s(char16_t *restrict c16s, const char *restrict s, size_t n, mbstate *restrict ps)
> ```
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>mbsrtoc16s</code></b> function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by s into a sequence of corresponding <code>char16_t</code> characters and stores not more than <code>n</code> <code>char16_t</code> characters into the array pointed to by <code>c16s</code>.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <b><code>mbrtoc16</code></b> function with <b><code>MB_MAX_LEN</code></b> for <code>n</code>. However, no multibyte characters that follow a null character (which is converted into a null <code>char16_t</code> character) will be examined or converted.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a multibyte character is encountered that does not correspond to a valid sequence of <code>char16_t</code> characters, the <b><b><code>mbsrtoc16s</code></b></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><b><code>mbsrtoc16s</code></b></b> function returns the number of array elements modified, not including a terminating null <code>char16_t</code> character, if any.</ins></p>

> <p><ins><b>7.28.3.2 The <b><code>c16srtombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c16srtombs(char *restrict s, const char16_t *restrict c16s, size_t n, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c16srtombs</code></b> function converts a sequence of <code>char16_t</code> characters from the array pointed to by c16s into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if a null character is stored.</ins></p>
> 
> <p><ins><sup>3</sup> Each sequence of <code>char16_t</code> characters is converted as if by calls to the c16rtomb function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a sequence of <code>char16_t</code> characters is encountered that does not correspond to a valid multibyte character, the c16srtombs function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c16srtombs</code></b> function returns the number of bytes modified, not including a terminating null character, if any.</ins></p>

> <p><ins><b>7.28.3.3 The <b><code>mbsrtoc32s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbsrtoc32s(char32_t *restrict c32s, const char *restrict s, size_t n, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The mbsrtoc32s function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char32_t</code> characters and stores not more than <code>n</code> <code>char32_t</code> characters into the array pointed to by <code>c32s</code>.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <code>mbrtoc32</code> function with <code>MB_MAX_LEN</code> for <code>n</code>. However, no multibyte characters that follow a null character (which is converted into a null <code>char32_t</code> character) will be examined or converted.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If an invalid multibyte character is encountered, the <b><code>mbsrtoc32s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>mbsrtoc32s</code></b> function returns the number of array elements modified, not including a terminating null <code>char32_t</code> character, if any.</ins></p>

> <p><ins><b>7.28.3.4 The <b><code>c32srtombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c32srtombs(char *restrict s, const char32_t *restrict c32s, size_t n, mbstate *restrict ps)>
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c32srtombs</code></b> function converts a sequence of <code>char32_t</code> characters from the array pointed to by c32s into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if a null character is stored.</ins></p>
> 
> <p><ins><sup>3</sup>Each <code>char32_t</code> character is converted as if by calls to the <code>c32rtomb</code> function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a <code>char32_t</code> character is encountered that does not correspond to a valid multibyte character, the <b><code>c32srtombs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c32srtombs</code></b> function returns the number of bytes modified, not including a terminating null character, if any.</ins></p>

> <p><ins><b>7.28.3.5 The <b><code>mbsnrtoc16s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbsnrtoc16s(size_t c16n, char16_t *restrict c16s, size_t n, const char *restrict s, mbstate* ps)
> ```
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>mbsnrtoc16s</code></b> function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char16_t</code> characters and stores not more than <code>c16n</code> <code>char16_t</code> characters into the array pointed to by <code>c16s</code>. It does not convert more than <code>n</code> multibyte characters.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <b><code>mbrtoc16</code></b> function with <b><code>MB_MAX_LEN</code></b> for <code>n</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a multibyte character is encountered that does not correspond to a valid sequence of <code>char16_t</code> characters, the <b><code>mbsnrtoc16s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>mbsnrtoc16s</code></b> function returns the number of array elements modified.</ins></p>

> <p><ins><b>7.28.3.6 The <b><code>c16snrtombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c16snrtombs(size_t n, char *restrict s, size_t c16n, const char16_t *restrict c16s, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c16snrtombs</code></b> function converts a sequence of <code>char16_t</code> characters from the array pointed to by <code>c16s</code> into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if the limit of <code>c16n</code> elements is converted.</ins></p>
> 
> <p><ins><sup>3</sup> Each sequence of <code>char16_t</code> characters is converted as if by calls to the <code>c16rtomb</code> function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a sequence of <code>char16_t</code> characters is encountered that does not correspond to a valid multibyte character, the <b><code>c16snrtombs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c16snrtombs</code></b> function returns the number of bytes modified.</ins></p>

> <p><ins><b>7.28.3.7 The <b><code>mbsnrtoc32s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t mbsnrtoc32s(size_t c32n, char32_t *restrict c32s, size_t n, const char *restrict s, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>mbsnrtoc32s</code></b> function converts a sequence of multibyte characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char32_t</code> characters and stores not more than <code>c32n</code> <code>char32_t</code> characters into the array pointed to by <code>c32s</code>. It does not convert more than <code>n</code> multibyte characters.</ins></p>
> 
> <p><ins><sup>3</sup> Each multibyte character is converted as if by a call to the <code>mbrtoc32</code> function with <code>MB_MAX_LEN</code> for <code>n</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If an invalid multibyte character is encountered, the <b><code>mbsnrtoc32s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>mbsnrtoc32s</code></b> function returns the number of array elements modified.</ins></p>

> <p><ins><b>7.28.3.8 The <b><code>c32snrtombs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c32snrtombs(size_t n, char *restrict s, size_t c32n, const char32_t *restrict c32s, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c32snrtombs</code></b> function converts a sequence of <code>char32_t</code> characters from the array pointed to by c32s into a sequence of corresponding multibyte characters that begins in the initial shift state, and stores these multibyte characters into the array pointed to by <code>s</code>, stopping if a multibyte character would exceed the limit of <code>n</code> total bytes or if the limit of <code>c32n</code> elements is converted.</ins></p>
> 
> <p><ins><sup>3</sup>Each <code>char32_t</code> character is converted as if by calls to the <code>c32rtomb</code> function with a non-null <code>ps</code>.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a <code>char32_t</code> character is encountered that does not correspond to a valid multibyte character, the <b><code>c32snrtombs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c32snrtombs</code></b> function returns the number of bytes modified.</ins></p>

> <p><ins><b>7.28.3.9 The <b><code>wcsrtoc16s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t wcsrtoc16s(char16_t *restrict c16s, const wchar_t *restrict s, size_t n, mbstate *restrict ps)
> ```
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>wcsrtoc16s</code></b> function converts a sequence of wide characters that begins in the initial shift state from the array pointed to by s into a sequence of corresponding <code>char16_t</code> characters and stores not more than <code>n</code> <code>char16_t</code> characters into the array pointed to by <code>c16s</code>.</ins></p>
> 
> <p><ins><sup>3</sup> Each wide character is converted as if by a call to the <b><code>wcrtoc16</code></b> function. However, no wide characters that follow a null character (which is converted into a null <code>char16_t</code> character) will be examined or converted.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a wide character is encountered that does not correspond to a valid sequence of <code>char16_t</code> characters, the <b><b><code>wcsrtoc16s</code></b></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><b><code>wcsrtoc16s</code></b></b> function returns the number of array elements modified, not including a terminating null <code>char16_t</code> character, if any.</ins></p>

> <p><ins><b>7.28.3.10 The <b><code>c16srtowcs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c16srtowcs(wchar_t *restrict s, const char16_t *restrict c16s, size_t n, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c16srtowcs</code></b> function converts a sequence of <code>char16_t</code> characters from the array pointed to by c16s into a sequence of corresponding wide characters that begins in the initial shift state, and stores these wide characters into the array pointed to by <code>s</code>, stopping if a wide character would exceed the limit of <code>n</code> total bytes or if a null character is stored.</ins></p>
> 
> <p><ins><sup>3</sup> Each sequence of <code>char16_t</code> characters is converted as if by calls to the c16rtomb function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a sequence of <code>char16_t</code> characters is encountered that does not correspond to a valid wide character, the c16srtowcs function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c16srtowcs</code></b> function returns the number of bytes modified, not including a terminating null character, if any.</ins></p>

> <p><ins><b>7.28.3.11 The <b><code>wcsrtoc32s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t wcsrtoc32s(char32_t *restrict c32s, const wchar_t *restrict s, size_t n, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The wcsrtoc32s function converts a sequence of wide characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char32_t</code> characters and stores not more than <code>n</code> <code>char32_t</code> characters into the array pointed to by <code>c32s</code>.</ins></p>
> 
> <p><ins><sup>3</sup> Each wide character is converted as if by a call to the <code>wcrtoc32</code> function. However, no wide characters that follow a null character (which is converted into a null <code>char32_t</code> character) will be examined or converted.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If an invalid wide character is encountered, the <b><code>wcsrtoc32s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>wcsrtoc32s</code></b> function returns the number of array elements modified, not including a terminating null <code>char32_t</code> character, if any.</ins></p>

> <p><ins><b>7.28.3.12 The <b><code>c32srtowcs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c32srtowcs(wchar_t *restrict s, const char32_t *restrict c32s, size_t n, mbstate *restrict ps)>
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c32srtowcs</code></b> function converts a sequence of <code>char32_t</code> characters from the array pointed to by c32s into a sequence of corresponding wide characters that begins in the initial shift state, and stores these wide characters into the array pointed to by <code>s</code>, stopping if a wide character would exceed the limit of <code>n</code> total bytes or if a null character is stored.</ins></p>
> 
> <p><ins><sup>3</sup>Each <code>char32_t</code> character is converted as if by calls to the <code>c32rtomb</code> function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a <code>char32_t</code> character is encountered that does not correspond to a valid wide character, the <b><code>c32srtowcs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c32srtowcs</code></b> function returns the number of bytes modified, not including a terminating null character, if any.</ins></p>
> <p><ins><b>7.28.3.13 The <b><code>wcsnrtoc16s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t wcsnrtoc16s(size_t c16n, char16_t *restrict c16s, size_t n, const wchar_t *restrict s, mbstate* ps)
> ```
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>wcsnrtoc16s</code></b> function converts a sequence of wide characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char16_t</code> characters and stores not more than <code>c16n</code> <code>char16_t</code> characters into the array pointed to by <code>c16s</code>. It does not convert more than <code>n</code> wide characters.</ins></p>
> 
> <p><ins><sup>3</sup> Each wide character is converted as if by a call to the <b><code>wcrtoc16</code></b> function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a wide character is encountered that does not correspond to a valid sequence of <code>char16_t</code> characters, the <b><b><code>wcsnrtoc16s</code></b></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><b><code>wcsnrtoc16s</code></b></b> function returns the number of array elements modified.</ins></p>

> <p><ins><b>7.28.3.14 The <b><code>c16snrtowcs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c16snrtowcs(size_t n, wchar_t *restrict s, size_t c16n, const char16_t *restrict c16s, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c16snrtowcs</code></b> function converts a sequence of <code>char16_t</code> characters from the array pointed to by <code>c16s</code> into a sequence of corresponding wide characters that begins in the initial shift state, and stores these wide characters into the array pointed to by <code>s</code>, stopping if a wide character would exceed the limit of <code>n</code> total bytes or if the limit of <code>c16n</code> elements is converted.</ins></p>
> 
> <p><ins><sup>3</sup> Each sequence of <code>char16_t</code> characters is converted as if by calls to the <code>c16rtomb</code> function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a sequence of <code>char16_t</code> characters is encountered that does not correspond to a valid wide character, the <b><code>c16snrtowcs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c16snrtowcs</code></b> function returns the number of bytes modified.</ins></p>

> <p><ins><b>7.28.3.15 The <b><code>wcsnrtoc32s</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t wcsnrtoc32s(size_t c32n, char32_t *restrict c32s, size_t n, const wchar_t *restrict s, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>wcsnrtoc32s</code></b> function converts a sequence of wide characters that begins in the initial shift state from the array pointed to by <code>s</code> into a sequence of corresponding <code>char32_t</code> characters and stores not more than <code>c32n</code> <code>char32_t</code> characters into the array pointed to by <code>c32s</code>. It does not convert more than <code>n</code> wide character.</ins></p>
> 
> <p><ins><sup>3</sup> Each wide character is converted as if by a call to the <code>wcrtoc32</code> function.</ins></p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If an invalid wide character is encountered, the <b><code>wcsnrtoc32s</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>wcsnrtoc32s</code></b> function returns the number of array elements modified.</ins></p>

> <p><ins><b>7.28.3.16 The <b><code>c32snrtowcs</code></b> function</b></ins></p>
> 
> <p>&emsp;<ins><b>Synopsis</b></ins></p>
> 
> <p><ins><sup>1</sup></ins></p>
> ```cpp
> #include <uchar.h>
> size_t c32snrtowcs(size_t n, wchar_t *restrict s, size_t c32n, const char32_t *restrict c32s, mbstate *restrict ps)
> ```
> 
> <p>&emsp;<ins><b>Description</b></ins></p>
> 
> <p><ins><sup>2</sup> The <b><code>c32snrtowcs</code></b> function converts a sequence of <code>char32_t</code> characters from the array pointed to by c32s into a sequence of corresponding wide characters that begins in the initial shift state, and stores these wide characters into the array pointed to by <code>s</code>, stopping if a wide character would exceed the limit of <code>n</code> total bytes or if the limit of <code>c32n</code> elements is converted.</ins></p>
> 
> <p><ins><sup>3</sup>Each <code>char32_t</code> character is converted as if by calls to the <code>c32rtomb</code> function with a non-null <code>ps</code></ins>.</p>
> 
> <p>&emsp;<ins><b>Returns</b></ins></p>
> 
> <p><ins><sup>4</sup> If a <code>char32_t</code> character is encountered that does not correspond to a valid wide character, the <b><code>c32snrtowcs</code></b> function returns <code>(size_t)(-1)</code>. Otherwise, the <b><code>c32snrtowcs</code></b> function returns the number of bytes modified.</ins></p>




# Conclusion

The ecosystem deserves ways to get to a statically-known encoding and not rely on implementation and locale-parameterized encodings. This allows developers a way to perform cross-platform text processing without needing to go through fantastic gymnastics to support different languages and platforms. An independent library implementation, _cuneicode_<sup>\[7\]</sup> is available upon request to the author. A patch to musl-libc will be available by the 2020 Freiburg, Germany meeting.



# Acknowledgements

Thank you to Philipp K. Krause for responding to the e-mails of a newcomer to matters of C and providing me with helpful guidance. Thank you to Rajan Bhakta, Daniel Plakosh, and David Keaton for guidance on how to submit these papers and get started in WG14. Thank you to Tom Honermann for lighting the passionate fire for proper text handling in me for not just C++, but for our sibling language C.

<div class="pagebreak"></div>



# References

\[1\]: Philip K. Krause. N2282: Additional multibyte/wide string conversion functions. June 2018. Published: [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2282.htm](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2282.htm).  
\[2\]: WG14. Clarification Request Summary for C11, Version 1.13. October 2017. Published: [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2244.htm](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2244.htm).  
\[3\]: ISO/IEC, WG14. Programming Languages - C (Committee Draft). April 12, 2011. Published: [http://www.open-std.org/jtc1/sc22/WG14/www/docs/n1570.pdf](http://www.open-std.org/jtc1/sc22/WG14/www/docs/n1570.pdf).  
\[4\]: Henri Sivonen. `encoding_rs`: a Web-Compatible Character Encoding Library in Rust. December 2018. Published: [https://hsivonen.fi/encoding_rs/#results](https://hsivonen.fi/encoding_rs/#results).  
\[5\]: Bob Steagall. Fast Conversion From UTF-8 with C++, DFAs, an SSE Intrinsics. September 2018. Published: [https://www.youtube.com/watch?v=5FQ87-Ecb-A](https://www.youtube.com/watch?v=5FQ87-Ecb-A)  
\[6\]: Robot Martinho Fernandes. p1041. February 2019. Published: [https://wg21.link/p1041](https://wg21.link/p1041).  
\[7\]: JeanHeyd Meneide. Cuneicode. November 2019. Published Meeting C++: [https://www.youtube.com/watch?v=FQHofyOgQtM](https://www.youtube.com/watch?v=FQHofyOgQtM).

<sub><sub><sub>May the Tower of Babel's curse be defeated.</sub></sub></sub>
