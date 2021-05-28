---
title: char16_t & char32_t string literals shall be UTF-16 & UTF-32 | r0
date: May 15th, 2021
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
layout: paper
hide: true
---

_**Document**_: n2728  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: Change Request  
_**Target Audience**_: General Developers, Library Developers  
_**Latest Revision**_: [https://thephd.dev/_vendor/future_cxx/papers/C%20-%20char16_t%20&%20char32_t%20string%20literals%20shall%20be%20UTF-16%20&%20UTF-32.html](https://thephd.dev/_vendor/future_cxx/papers/C%20-%20char16_t%20&%20char32_t%20string%20literals%20shall%20be%20UTF-16%20&%20UTF-32.html)

<div class="text-center">
<h6>Abstract:</h6>
<p>
This paper closes a as-yet unused degree of freedom in string literal representations. We observe that wide string literals and narrow string literals provide the implementation-defined flexibility that vendors need for choosing an arbitrary representation, and that no vendor (that we currently know of) has taken advantage of such functionality for char16_t and char32_t string literals. Therefore, we are hoping to settle on UTF-16 and UTF-32 for char16_t literals, similar to have u8-string literals are defined to be UTF-8.
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 0

- Initial release! 🎉




# Introduction & Motivation

Of all the string literal types, only one of them carries a well-defined encoding according to the standard:

- ❌ `char`/narrow/"multibyte" strings and string literals - narrow locale encoding or execution encoding, implementation-defined;
- ❌ `wchar_t`/wide strings and string literals - narrow locale encoding or execution encoding, implementation-defined and tied to `mbstowcs`;
- ☑️ `u8`/`char` strings and string literals - UTF-8 encoding (when not confused for normal `char` literals by the type system);
- ❌ `u`/`char16_t` strings and string literals - implementation-defined encoding tied to `mbrtoc16`;
- ❌ `U`/`char32_t` strings and string literals - implementation-defined encoding tied to `mbrtoc32`;

Narrow/multibyte strings and literals have uncountably many applied encodings at translation time and execution time in practice. Wide strings and literals have encodings such as UCS-2 or UTF-16, UTF-32, EUC-TW and EUC-JP in practice. These encodings are determined at translation time, and not execution time.



## "What, exactly, is in my String Literal?"

The side-effect of the existing practice is that almost no existing implementation can or has been matching a potentially valid reading of §6.4.5 String literals, paragraph 6. According to the standard, each string literal matches the `mbrtoc16/32` or `mbstowcs` functions; this would imply that there is a translation-time encoding used, or that string literals are tied to an execution-time property. It is unclear whether there exists any implementation that, after compilation, inserts code that reacts to `setlocale` and transcodes all existing string literals to the new locale of the program. There does not seem to exist any interpreters that behave in this manner, either.

The alternative explanation is that the encoding of the string is only determined at the point of creation, and that strings later in the program translation can be affected if they are created after a call to `setlocale`. This interpretation, while granting clemency to any vendor that has created strings with a fixed encoding even in an interpreter-like implementation, still presents the incredibly awkward problem that strings become a property of the translation of the program, and brings up very interesting consequences if an implementation allows for someone to set the encoding of their string literals in the middle of their program. This still runs the risk of not being identical to what `mbstowcs` or `mbrtoc16/32` do at program runtime, even if the program never calls `setlocale`.

Notably, neither of these (valid) interpretations is useful, worthwhile, or reflect today's existing practice.



## Execution Time vs. Translation Time

It's also important to note that traditional compilers can, have, and do create wide (`L`) and normal string literals based on a compile-time encoding that does not match the run-time encoding. The specification as it is underserves implementations by tying them to a property they have not been able to provide since the earliest days of `setlocale`, and in doing so has introduced an unnecessary schism in what can be guaranteed at translation time and execution time.

Thanks to the unending and unyielding pain that both of these two have provided us, the industry for the last decade has settled very strongly on UTF-8, UTF-16, and UTF-32 for the encoding of `u8`, `char16_t`, and `char32_t` strings and string literals. The standard only mandates this behavior for `u8`; the other two are left as implementation-defined (and tied to the `locale`), with a Macro that says whether or not it supports any of the Unicode code points specified in ISO 10646 (but without specifying the underlying encoding still). We know of no implementation that ships on any system large or small that uses a different encoding for `u8`, `char16_t`, or `char32_t` strings and string literals.

Normally, more freedom tends to be a good thing for implementations, but there is an enormous risk to the ecosystem by continuing to leave this freedom open. As we have experienced with `"abc"` and `L"abc"` literals and their associated locale-based encodings, the entire ecosystem is plagued with Mojibake or similar issues when software is transferred across computers and to different regions and domains, through different systems with different defaults, and more.




# Solution

Therefore, this paper proposes to solidify what is existing practice in almost every single compiler known to date. All `char16_t` strings and literals shall be UTF-16 encoded, and all `char32_t` strings and literals shall be UTF-32 encoded, unless otherwise explicitly specified.

We settle on this solution because it is existing practice. A survey of implementations overseen by Tom Honermann of Synopsys through Coverity as well as reaching out to certain vendors for confirmation has revealed that there exists no implementation which interprets `char16_t` or `char32_t` literals as anything other than UTF-16 or UTF-32. All of the major compilers also follow this behavior (GCC, ICC, Clang, IBM xlC/C++, TinyCC, SDCC, EDG C and C++ in all of its modes, MSVC, IAR C/C++ Compilers, Embarcadero C, and more).

To achieve our goal, we state this in the front-matter for "string literals". We then provide wording in other relevant places for `char16_t` and `char32_t` functions that state the desired encoding (UTF-16 and UTF-32 respectively). Finally, we disentangle the compile-time encoding of string literals and the locale-based functions.

Note that the disentanglement does not reduce implementer freedom. The encoding for string literals and `wchar_t` string literals is still implementation-defined; it is just explicitly defined as such now and no longer makes any forward mention of `mbtowc`, `mbstowcs`, `mbrtoc16` or `mbrtoc32`. The conversion from the translation time execution character set to the *literal* and *wide literal encoding* is **still** completely implementation-defined; that means implementations can continue to:

- call `mbtowc`/`mbstowcs` and friends on their Host platform (a very literal interpretation) to encode/decode string literals from the execution character set (older compilers relying directly on the packaged C library)
- ignore those completely and do whatever `-fexec-charset=owo` + `-fwide-exec-charset=òwó`, or `/execution-charset:uwu`, are supposed to accomplish (GCC, MSVC, and many others)
- take the flag `-fexec-charset=owo` and completely ignore it (Clang)
- and more!

This is, essentially, an expansion of an implementation's rights for normal and wide string literals. In exchange, we reduce hypothetical implementer freedom in exchange for programmer guarantees by making `char16_t` and `char32_t` be UTF-16 and UTF-32. We, once again, note that no implementer has taken advantage of this flexibility since 2006 when these features were first being cooked up by the C Standards Committee.


## Do We Need Other References?

No. ISO/IEC 10646 is kept as an undated reference in the C Standard, which means it always refers to the latest standard. UTF-8, UTF-16, and UTF-32 are all mentioned and described in ISO/IEC 10646. Therefore the wording can reference this terminology directly, by reference, as it does with UTF-8.




# Wording

The following wording is relative to [N2596](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf).



## Add 1 new subclause to §6.2 Concepts for encodings

<blockquote>
<ins>
<h6><b>6.2.9 Encodings</b></h6>

<p><sup>1</sup> The <i>literal encoding</i> is an implementation-defined mapping of the characters of the execution character set to the values in a character constant (6.4.4.4) or string literal (6.4.5). It shall support a mapping from all the basic execution character set values into the implementation-defined encoding. It may contain multibyte character sequences (5.2.1.2).</p>

<p><sup>2</sup> The <i>wide literal encoding</i> is an implementation-defined mapping of the characters of the execution character set to the values in a `wchar_t` character constant (6.4.4.4) or a `wchar_t` string literal (6.4.5). It shall support a mapping from all the basic execution character set values into the implementation-defined encoding. The mapping shall produce values identical to the literal encoding for all the basic execution character set values if an implementation does not define `__STDC_MB_MIGHT_NEQ_WC__`. One or more values may map to one or more values of the extended execution character set.</p>
</ins>
</blockquote>



## Modify §6.4.4.4 Character constants, paragraph 2

<blockquote>
<p><sup>2</sup> An <i>integer character constant</i> is a sequence of one or more multibyte characters enclosed in single-quotes, as in `'x'`. A <i>UTF–8 character constant</i> is the same, except prefixed by `u8`.<del> A wide character constant is the same, except prefixed by the letter `L`, `u`, or `U`.</del><ins> A <i>`wchar_t` character constant</i> is prefixed by the letter `L`. A <i>UTF-16 character constant</i> is prefixed by the letter `u`. A <i>UTF-32 character constant</i> is prefixed by the letter `U`. Collectively, `wchar_t`, UTF-16, and UTF-32 character constants are called <i>wide character constants</i>.</ins> With a few exceptions detailed later, the elements of the sequence are any members of the source character set; they are mapped in an implementation-defined manner to members of the execution character set.</p>
</blockquote>



## Modify §6.4.4.4 Character constants, paragraph 10 - 11

<blockquote>
<p><sup>10</sup> A UTF–8<ins>, UTF-16, or UTF-32</ins> character constant shall not contain more than one character.<sup>85)</sup> The value shall be representable with a single UTF–8<ins>, UTF-16, or UTF-32</ins> code unit.</p>

<h6><b>Semantics</b></h6>

<p><sup>11</sup>An integer character constant has type `int`. The value of an integer character constant containing a single character that maps to a <del>single-byte execution character</del><ins>single value in the literal encoding</ins> is the numerical value of the representation of the mapped character <ins>in the literal encoding</ins> interpreted as an integer. The value of an integer character constant containing more than one character (e.g., `'ab'`), or containing a character or escape sequence that does not map to <del>a single-byte execution character</del><ins>a single value in the literal encoding</ins>, is implementation-defined.</p>
</blockquote>



## Rewrite §6.4.4.4 Character constants, paragraph 12 and 13, and insert 2 new paragraphs before 13 (making it 15)

<blockquote>
<p><sup>12</sup> <del>A UTF–8 character constant has type `unsigned char` which is an unsigned integer types defined in the `<uchar.h>` header. The value of a UTF–8 character constant is equal to its ISO/IEC 10646 code point value, provided that the code point value can be encoded as a single UTF–8 code unit.</del><ins>A UTF–8 character constant has type `unsigned char`. If the UTF-8 character constant is not produced through a hexadecimal or octal escape sequence, the value of a UTF–8 character constant is equal to its ISO/IEC 10646 code point value, provided that the code point value can be encoded as a single UTF–8 code unit. Otherwise, the value of the UTF-8 character constant is the numeric value specified in the hexadecimal or octal escape sequence.</ins></p>

<p><ins><sup>13</sup>A UTF–16 character constant has type `char16_t` which is an unsigned integer types defined in the `<uchar.h>` header. If the UTF-16 character constant is not produced through a hexadecimal or octal escape sequence, the value of a UTF–16 character constant is equal to its ISO/IEC 10646 code point value, provided that the code point value can be encoded as a single UTF–16 code unit. Otherwise, the value of the UTF-16 character constant is the numeric value specified in the hexadecimal or octal escape sequence.</ins></p>

<p><ins><sup>14</sup>A UTF–32 character constant has type `char32_t` which is an unsigned integer types defined in the `<uchar.h>` header. If the UTF-32 character constant is not produced through a hexadecimal or octal escape sequence, the value of a UTF–32 character constant is equal to its ISO/IEC 10646 code point value, provided that the code point value can be encoded as a single UTF–32 code unit. Otherwise, the value of the UTF-32 character constant is the numeric value specified in the hexadecimal or octal escape sequence.</ins></p>

<p><sup><del>13</del><ins>15</ins></sup> <ins>A `wchar_t` character constant prefixed by the letter `L` has type `wchar_t`, an integer type defined in the `<stddef.h>` header. The value of a `wchar_t` character constant containing a single multibyte character that maps to a single member of the extended execution character set is the wide character corresponding to that multibyte character in the implementation-defined wide literal encoding. The value of a wide character constant containing more than one multibyte character or a single multibyte character that maps to multiple members of the extended execution character set, or containing a multibyte character or escape sequence not represented in the extended execution character set, is implementation-defined.</ins></p>
</blockquote>



## Modify §6.4.5 String literals, paragraph 3 and 6

<blockquote>
<p><sup>3</sup>... A <i>UTF–8 string literal</i> is the same, except prefixed by `u8`.<ins> A <i>`wchar_t` string literal</i> is the same, except prefixed by `L`. A <i>UTF–16 string literal is the same, except prefixed by `u`. A <i>UTF–32 string literal</i> is the same, except prefixed by `u8`.</ins> <del>A wide string literal</i> is the same, except prefixed by the letter `L`, `u`, or `U`.</del><ins>Collectively, `wchar_t`, UTF-16, and UTF-32 string literals are called <i>wide string literals</i>.</ins></p>

<p>...</p>

<p><sup>6</sup> In translation phase 7, a byte or code of value zero is appended to each multibyte character sequence that results from a string literal or literals.<sup>86)</sup> The multibyte character sequence is then used to initialize an array of static storage duration and length just sufficient to contain the sequence. For character string literals, the array elements have type `char`, and are initialized with the individual bytes of the multibyte character sequence <ins>corresponding to the literal encoding</ins>. For UTF–8 string literals, the array elements have type `char`, and are initialized with the characters of the multibyte character sequence, as encoded in UTF–8. For wide string literals prefixed by the letter `L`, the array elements have type `wchar_t` and are initialized with the sequence of wide characters corresponding <del>to the multibyte character sequence, as defined by the `mbstowcs` function with an implementation-defined current locale.</del><ins>to the wide literal encoding</ins> For wide string literals prefixed by the letter `u` or `U`, the array elements have type `char16_t` or `char32_t`, respectively, and are initialized with the <del>sequence of wide characters corresponding to the multibyte character sequence, as defined by successive calls to the `mbrtoc16`, or `mbrtoc32` function as appropriate for its type, with an implementation-defined current locale</del><ins>sequence of wide characters corresponding to UTF-16 and UTF-32 encoded text, respectively</ins>. The value of a string literal containing a multibyte character or escape sequence not represented in the execution character set is implementation-defined.<ins> Any hexadecimal escape sequence or octal escape sequence specified in a `u8`, `u`, or `U` specifies a single `char`, `char16_t`, or `char32_t` value and may result in the full character sequence not being valid UTF-8, UTF-16, or UTF-32.</ins></p>
</blockquote>



## Add the `__STDC_UTF_16__` and `__STDC_UTF_32__` Macros to  §6.10.8.1 Mandatory Macros so that they are always defined

<blockquote>
<p><sup>1</sup> The following macro names shall be defined by the implementation:</p>
<p>...</p>
<blockquote>
<ins>
<p>`__STDC_UTF_16__` The integer constant `1`, intended to indicate that values of type `char16_t` are UTF–16 encoded.</p>
<p>`__STDC_UTF_32__` The integer constant `1`, intended to indicate that values of type `char32_t` are UTF–32 encoded.</p>
</ins>
</blockquote>
</blockquote>



## Remove the `__STDC_UTF_16__` and `__STDC_UTF_32__` Macros from §6.10.8.2 Environment Macros

<blockquote>
<p><sup>1</sup> The following macro names are conditionally defined by the implementation:</p>
<p>...</p>
<blockquote>
<del>
<p>`__STDC_UTF_16__` The integer constant `1`, intended to indicate that values of type `char16_t` are UTF–16 encoded. If some other encoding is used, the macro shall not be defined and the actual encoding used is implementation-defined.</p>
<p>`__STDC_UTF_32__` The integer constant `1`, intended to indicate that values of type `char32_t` are UTF–32 encoded. If some other encoding is used, the macro shall not be defined and the actual encoding used is implementation-defined.</p>
</del>
</blockquote>
</blockquote>



## Modify §J.3.4 bullet for implementation-defined behavior

<blockquote>
<p><del>
— The encoding of any of `wchar_t`, `char16_t`, and `char32_t` where the corresponding standard encoding macro (`__STDC_ISO_10646__`, `__STDC_UTF_16__`, or `__STDC_UTF_32__`) is not defined (6.10.8.2).
</del></p>
<p><ins>
— The encoding of any of `wchar_t` where the corresponding standard encoding macro (`__STDC_ISO_10646__`) is not defined (6.10.8.2).
</ins></p>
</blockquote>
