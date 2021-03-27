---
title: char16_t & char32_t string literals shall be UTF-16 & UTF-32 | r0
date: March 21st, 2021
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
layout: paper
hide: true
---

_**Document**_: n26XX  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: Change Request  
_**Target Audience**_: General Developers, Library Developers  
_**Latest Revision**_: [https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20char16_t%20&%20char32_t%20string%20literals%20shall%20be%20UTF-16%20&%20UTF-32.html](https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20char16_t%20&%20char32_t%20string%20literals%20shall%20be%20UTF-16%20&%20UTF-32.html)

<div class="text-center">
<h6>Abstract:</h6>
<p>
This paper closes a as-yet unused degree of freedom in string literal representations. We observe that wide string literals and narrow string literals provide the implementation-definedness that vendors need for choosing an arbitrary representation, and that no vendor (that we currently know of) has taken advantage of such functionality for char16_t and char32_t string literals. Therefore, we are hoping to settle on UTF-16 and UTF-32 for char16_t literals, similar to have u8-string literals are defined to be UTF-8.
</p>
</div>

<div class="pagebreak"></div>




# Introduction & Motivation

Of all the string literal types, only one of them carries a well-defined encoding according to the standard:

- ❌ `char`/narrow/"multibyte" strings and string literals - narrow locale encoding or execution encoding, implementation-defined;
- ❌ `wchar_t`/wide strings and string literals - narrow locale encoding or execution encoding, implementation-defined and tied to `mbstowcs`;
- ☑️ `u8`/`char` strings and string literals - UTF-8 encoding (when not confused for normal `char` literals by the type system);
- ❌ `u`/`char16_t` strings and string literals - implementation-defined encoding tied to `mbrtoc16`;
- ❌ `U`/`char32_t` strings and string literals - implementation-defined encoding tied to `mbrtoc32`;

Narrow/multibyte strings and literals have uncountably many applied encodings at translation time and execution time in practice. Wide strings and literals have encodings such as UCS-2 or UTF-16, UTF-32, EUC-TW and EUC-JP in practice. It is also unclear whether there exists any implementation that, after compilation, inserts code that reacts to `setlocale` and transcodes all existing strings to the new locale of the program. There does not seem to exists any interpreters that behave in this manner either. This means that almost no existing implementation can or has been matching the interpretation of §6.4.5 String literals, paragraph 6, where each string literal matches the `mbrtoc16/32` or `mbstowcs` functions. The alternative explanation is that the encoding of the string is only determined at the point of creation, and that strings later in the program could be affected if they are created after a call to `setlocale`. This interpretation, while granting clemency to any vendor that has created strings with a fixed encoding even in an interpreter-like implementation, still presents the incredibly awkward problem that strings become a property of the execution of the program.

Neither of these interpretations is useful, worthwhile, or reflect today's existing practice.

It's also important to note that traditional compilers can, and have, created wide (`L`) and narrow string literals based on a compile-time encoding that does not match the run-time encoding used within functions such as `mbstowcs`. The specification as it is underserves implementations by tying them to a property they have not been able to provide since the earliest days of `setlocale`, and in doing so has introduced an unnecessary schism in what can be guaranteed at translation time and execution time.

Thanks to the unending and unyielding pain that both of these two have provided us, the industry for the last decade has settled very strongly on UTF-8, UTF-16, and UTF-32 for the encoding of `u8`, `char16_t`, and `char32_t` strings and string literals. The standard only mandates this behavior for `u8`; the other two are left as implementation-defined (and tied to the encoding), with a Macro that says whether or not it supports any of the Unicode code points specified in ISO 10646 (but without specifying the underlying encoding still). We know of no implementation that ships on any system large or small that uses a different encoding for `u8`, `char16_t`, or `char32_t` strings and string literals.

Normally, more freedom tends to be a good thing for implementations, but there is an enormous risk to the ecosystem by not closing this hole. As we have experienced with `"abc"` and `L"abc"` literals and their associated locale-based encodings, the entire ecosystem is plagued with Mojibake or similar issues when software is transferred across computers and to different regions and domains, through different systems with different defaults, and more.



# Solution

Therefore, this paper proposes to solidify what is existing practice in almost every single compiler known to date. All `char16_t` strings and literals shall be UTF-16 encoded, and all `char32_t` strings and literals shall be UTF-32 encoded, unless otherwise explicitly specified.

We settle on this solution because it is existing practice. A survey of implementations overseen by Tom Honermann of Synopsys through Coverity has revealed that there exists no implementation which interprets `char16_t` or `char32_t` literals as anything other than UTF-16 or UTF-32. All of the major compilers also follow this behavior (GCC, ICC, Clang, IBM xlC/C++, TinyCC, SDCC, EDG C and C++ in all of its modes, MSVC, IAR C/C++ Compilers, Embarcadero C, and more).

To do this, we simply state this in the front-matter for "string literals". We then provide wording in other relevant places for `char16_t` and `char32_t` functions that state the desired encoding (UTF-16 and UTF-32 respectively). Finally, we disentangle the compile-time encoding of string literals and the locale-based functions, stating that string literals used with these functions may have different encodings if `setlocale` is used.



# Wording

The following wording is relative to [N2596](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf).

## Modify §6.4.5 String literals

<blockquote>
<p><sup>6</sup> In translation phase 7, a byte or code of value zero is appended to each multibyte character sequence that results from a string literal or literals.<sup>86)</sup> The multibyte character sequence is then used to initialize an array of static storage duration and length just sufficient to contain the sequence. For character string literals, the array elements have type `char`, and are initialized with the individual bytes of the multibyte character sequence <ins>corresponding to an implementation-defined literal encoding</ins>. For UTF–8 string literals, the array elements have type `char`, and are initialized with the characters of the multibyte character sequence, as encoded in UTF–8. For wide string literals prefixed by the letter `L`, the array elements have type `wchar_t` and are initialized with the sequence of wide characters corresponding <del>to the multibyte character sequence, as defined by the `mbstowcs` function with an implementation-defined current locale.</del><ins>to an implementation-defined wide literal encoding</ins> For wide string literals prefixed by the letter `u` or `U`, the array elements have type `char16_t` or `char32_t`, respectively,and are initialized with the sequence of wide characters corresponding to the multibyte character sequence, as defined by successive calls to thembrtoc16, ormbrtoc32function as appropriate for its type, with an implementation-defined current locale. The value of a string literal containing a multibyte character or escape sequence not represented in the execution character set is implementation-defined.
</blockquote>
