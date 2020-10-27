---
title: Mixed Wide String Literal Concatenation
layout: page
date: October 26th, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
redirect_from:
  - /vendor/future_cxx/papers/source/n2594.html
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
</style>

_**Document**_: n2594  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Compiler/Tooling Developers  
_**Latest Revision**_: [https://thephd.github.io/vendor/future_cxx/papers/source/n2594.html](https://thephd.github.io/vendor/future_cxx/papers/source/n2594.html)

<p style="text-align: center">
<span style="font-style: italic; font-weight: bold">Abstract:</span>
<p>This paper removes the ability to concatenate wide string literals (<code>u</code>, <code>U</code>, and <code>L</code> prefixed) together if they have a different prefix.</p>
</p>

<div class="pagebreak"></div>


# Introduction & Motivation

This paper is a compatibility-parity and query paper to resolve a Liason request from WG21 - Programming Languages, C++. It is almost identical to [p2201](https://wg21.link/p2201).

String concatenation involving string-literals with encoding-prefixes mixing L"", u8"", u"", and U"" is currently conditionally-supported with implementation-defined behavior ([N2573 §6.4.5 String literals, Semantics, paragraph 5](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf)).

None of [icc, gcc, clang, MSVC supports such mixed concatenations; all issue an error](https://compiler-explorer.com/z/hx4TTf). Test code:

```cpp
void f() {

  { const void* a = L"" u""; }
  { const void* a = L"" u8""; }
  { const void* a = L"" U""; }

  { const void* a = u8"" L""; }
  { const void* a = u8"" u""; }
  { const void* a = u8"" U""; }

  { const void* a = u"" L""; }
  { const void* a = u"" u8""; }
  { const void* a = u"" U""; }

  { const void* a = U"" L""; }
  { const void* a = U"" u""; }
  { const void* a = U"" u8""; }
}
```

[SDCC, the Small Device C Compiler](http://sdcc.sourceforge.net/), does support such mixed concatenations, apparently taking the first encoding-prefix. One of its primary maintainers expressed sentiment that [the feature is not actually used much](http://open-std.org/jtc1/sc22/wg14/18105).

No meaningful use-case for such mixed concatenations is known, other than potential macro concatenation. However, no such usage experience was brought forth, and it is unlikely that code that uses multiple toolsets would be capable of taking advantage of such a feature since it is not present in many tools.

Therefore, this paper makes such mixed concatenations ill-formed.


# Wording

The following wording is relative to [N2573](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf).

**Add the following sentence to §6.4.5 String Literals, Constraints**

<blockquote>
<p><sup>2</sup> A sequence of adjacent string literal tokens shall not include both a wide string literal and a UTF–8 string literal. <ins>Adjacent wide string literal tokens shall have the same prefix.</ins></p>
</blockquote>

**Remove the following words §6.4.5 String literals, Semantics**

<blockquote>
<p><sup>5</sup> In translation phase 6, the multibyte character sequences specified by any sequence of adjacent character and identically-prefixed string literal tokens are concatenated into a single multibyte character sequence. If any of the tokens has an encoding prefix, the resulting multibyte character sequence is treated as having the same prefix; otherwise, it is treated as a character string literal. <del>Whether differently-prefixed wide string literal tokens can be concatenated and, if so, the treatment of the resulting multibyte character sequence are implementation-defined.</del></p>
</blockquote>
