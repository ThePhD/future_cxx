---
title: Restartable and Non-Restartable Functions for Efficient UTF Character Conversions | r0
date: December 5th, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis) \<<shepherd@soasis.org>\>
layout: paper
hide: true
---

_**Document**_: n26XX  
_**Previous Revisions**_: None
_**Audience**_: WG14  
_**Proposal Category**_: New Library Features  
_**Target Audience**_: General Developers, Text Processing Developers  
_**Latest Revision**_: [https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Efficient%20UTF%20Character%20Conversions.html](https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Efficient%20UTF%20Character%20Conversions.html)


<div class="text-center">
<h5>Abstract:</h5>
<p>
The Committee asked for UTF to UTF conversions as an addendum to an existing paper proposing implementation-specific functions.
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 0 - December 5th, 2020

- Create.




# Introduction and Motivation {#intro}

This paper is strictly an addendum after ISO/IEC JTC1 SC22 WG14 - Programming Languages, C voted for the authors of the original Efficient Character Conversions paper[^non-utf-functions] to bring forward a (separate) paper for UTF ↔ UTF transcoding functions. That is, the Committee very strongly recommended a paper for being able to convert text in one Unicode encodings to other Unicode encodings, particularly UTF-8, UTF-16, and UTF-32.

All of the motivation and reasoning for this paper and its sister paper can be found [here](https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Efficient%20Character%20Conversions.html). All of it applies identically to this paper.




# Wording {#wording}

The following wording is relative to [N2573](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf).

Note: The � is a stand-in character to be replaced by the editor.



## Intent {#wording-intent}

The intent of the wording is to provide transcoding functions that:

- define "code unit" as the smallest piece of information;
- define the notion of an "indivisible unit of work";
- convert from and to the unicode ("c8", "c16", "c32") encodings;
- provide a way to `mbstate_t` to be properly initialized as the initial conversion sequence; and,
- to be entirely thread-safe by default with no magic internal state asides from what is already required by locales.



## Proposed Library Wording {#wording-lib}

<blockquote>
<div class="wording-section">
<ins>
<p><h4><b>7.S� &emsp; Text transcoding utilities &lt;stdmchar.h&gt;</b></h4></p>

<div class="wording-numbered"><p>
The header &lt;stdmchar.h&gt; declares four status codes, five macros, types and functions for transcoding encoded text safely and effectively. It is meant to supersede and obsolete text conversion utilities from Unicode utilities (7.28) and Extended multibyte and wide character utilities (7.29). It is meant to represent "multi character" functions. These functions can be used to count the number of input that form a complete sequence, count the number of output characters required for a conversion with no additional allocation, validate an input sequence, or just convert some input text. Particularly, it provides single unit and multi unit output functions for transcoding by working on <i>code units</i>.
</p></div>

<div class="wording-numbered"><p>
A code unit is a single compositional unit of encoded information, usually of type <code class="c-kw">char</code>, <code class="c-kw">unsigned char</code>, <code class="c-kw">char16_t</code>, <code class="c-kw">char32_t</code>, or <code class="c-kw">wchar_t</code>. One or more code units are interpreted in a specific way specified by the related encoding of the operation. They are read until enough input to perform an <i>indivisible unit of work</i>. An indivisible unit is the smallest possible input, as defined by the encoding, that can produce either one or more outputs or perform a transformation of some internal state. The production of these indivisible units is called an <i>indivisible unit of work</i>, and they are used to complete the below specified transcoding operations. When an <i>indivisible unit of work</i> is successfully output, then the input is consumed by the below specified functions.
</p></div>

<div class="wording-numbered"><p>
The encodings supported are UTF-8, associated with <code class="c-kw">unsigned char</code>, UTF-16, associated with <code class="c-kw">char16_t</code>, and UTF-32, associated with <code class="c-kw">char32_t</code>.
</p></div>


<div class="wording-numbered"><p>
The types declared are <code class="c-kw">mbstate_t</code> (described in 7.29.1), <code class="c-kw">char16_t</code> (described in 7.28), <code class="c-kw">char32_t</code> (described in 7.28), <code class="c-kw">size_t</code> (described in 7.19), and;

> ```c
> mcerr_t
> ```

which is a type definition for a signed integer type which represents error codes returned from the functions below.
</p></div>

<div class="wording-numbered"><p>
The three macros declared are

> ```c
> STDC_C8_MAX
> STDC_C16_MAX
> STDC_C32_MAX
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
The error code values are integral constants of type <code class="c-kw">mcerr_t</code>, and are defined as follows:

> ```c
> const mcerr_t MCHAR_OK                  =  0;
> const mcerr_t MCHAR_ENCODING_ERROR      = -1;
> const mcerr_t MCHAR_INCOMPLETE_INPUT    = -2;
> const mcerr_t MCHAR_INSUFFICIENT_OUTPUT = -3;
> ```

Each value represents an error case when calling the relevant transcoding functions in &lt;stdmchar.h&gt;:

- `MCHAR_INSUFFICIENT_OUTPUT`, when the input is correct and an indivisible unit of work can be performed but there is not enough output space;
- `MCHAR_INCOMPLETE_INPUT`, when an incomplete input was found after exhausting the input'
- `MCHAR_ENCODING_ERROR`, when an encoding error occurred; and,
- `MCHAR_OK`, when the operation was successful.

No other value shall be returned from the functions described in this clause.
</p></div>

<p><b>Recommended Practice</b></p>
<div class="wording-numbered"><p>
The Maximum Output Macro values are intended for use in making automatic storage duration array declarations. Implementations should choose values for the macros that are spacious enough to accommodate a variety of underlying implementation choices for the target encodings supported by the narrow execution encodings and wide execution encodings. Below is a set of values that can be resilient to future additions and changes:

> ```c
> #define STDC_C8_MAX  32
> #define STDC_C16_MAX 16
> #define STDC_C32_MAX  8
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
> mcerr_t c8ntoc16n(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size);
> mcerr_t c8nrtoc16n(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mcerr_t c8ntoc32n(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size);
> mcerr_t c8nrtoc32n(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mcerr_t c16ntoc8n(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mcerr_t c16nrtoc8n(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mcerr_t c16ntoc32n(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mcerr_t c16nrtoc32n(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
>
> mcerr_t c32ntoc16n(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mcerr_t c32nrtoc16n(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mcerr_t c32ntoc8n(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mcerr_t c32nrtoc8n(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> ```

<div class="wording-numbered"><p>
Let:
<ul>
	<li><i>transcoding function</i> be one of the functions listed above transcribed in the form `mcerr_t XntoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size)`;</li>
	<li><i>restartable transcoding function</i> be one of the functions listed above transcribed in the form `mcerr_t XnrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state)`;</li>
	<li><i>X</i> and <i>Y</i> be one of the prefixes from the table from 7.S�;</li>
	<li><i>`charX`</i> and <i>`charY`</i> be the associated code unit types for <i>X</i> and <i>Y</i> from the table from 7.S�; and</li>
	<li><i>encoding X</i> and <i>encoding Y</i> be the associated encoding types for <i>X</i> and <i>Y</i> from the table from 7.S�.</li>
</ul>

The transcoding functions and restartable transcoding functions take an input buffer and an output buffer of the associated code unit types, potentially with their sizes. The function consumes any number of code units of type `charX` to perform a single indivisible unit of work necessary to convert some amount of input from encoding X to encoding Y, which results in zero or more output code units of type `charY`.
</p></div>

<p><b>Constraints</b></p>
<div class="wording-numbered"><p>
On success or failure, the transcoding functions and restartable transcoding functions shall return one of the above error codes (7.S�). `state` shall not be `NULL`. If `state` is not initialized to the initial conversion sequence for the function, or is used after being input into a function whose result was not one of `MCHAR_OK`, `MCHAR_INSUFFICIENT_OUTPUT`, or `MCHAR_INCOMPLETE_INPUT`, then the behavior of the functions is unspecified. For the restartable transcoding functions, if `input` is `NULL`, then `*state` is set to the initial conversion sequence as described below and no other work is performed. Otherwise, for both restartable and non-restartable functions, `input` must not be `NULL`.
</p></div>

<p><b>Semantics</b></p>
<div class="wording-numbered"><p>
The restartable transcoding functions take the form:

> ```c
> mcerr_t XnrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state);
> ```

They convert from code units of type `charX` interpreted according to encoding X to code units of type `charY` according to encoding Y given a conversion state of value `*state`. This function only performs a single indivisible unit of work. It does nothing and returns `MCHAR_OK` if the input is empty (only signified by `*input_size` is zero, if `input_size` is not `NULL`). The behavior of the restartable transcoding functions is as follows.

- If `input` is `NULL`, then `*state` is set to the initial conversion sequence associated with encoding X. The function returns `MCHAR_OK`.
- If `input_size` is not `NULL`, then the function reads code units from `*input` if `*input_size` is large enough to produce an indivisible unit of work. If no encoding errors have occurred but the input is exhausted before an indivisible unit of work can be computed, the function returns `MCHAR_INCOMPLETE_INPUT`.
- If `input_size` is `NULL`, then `*input` is incremented and read as if it points to a buffer of sufficient size for a successful operation. The behavior is undefined if the supplied input is not large enough.
- If `output` is `NULL`, then no output will be written. `*input` is still read and incremented.
- If `output_size` is not `NULL`, then `*output_size` will be decremented the amount of code units that would have been written to `*output` (even if `output` was `NULL`). If the output is exhausted (`*output_size` will be decremented below zero), the function returns `MCHAR_INSUFFICIENT_OUTPUT`.
- If `output_size` is `NULL` and output is not `NULL`, then enough space is assumed in the buffer pointed to by `*output` for the entire operation. The behavior is undefined if the output buffer is not large enough.
</p></div>

<div class="wording-numbered"><p>
If the function returns `MCHAR_OK`, then all of the following is true:

- `*input` will be incremented by the number of code units read and successfully converted;
- if `input_size` is not `NULL`, `*input_size` is decremented by the number of code units read and successfully converted from the input;
- if `output` is not `NULL`, `*output` will be incremented by the number of code units written to the output; and,
- if `output_size` is not `NULL`, `*output_size` is decremented by the number of code units written to the output.

Otherwise, an error is returned is none of the above occurs. If the return value is `MCHAR_ENCODING_ERROR`, then `*state` is in an unspecified state.
</p></div>

<div class="wording-numbered"><p>
The non-restartable transcoding functions take the form:

> ```c
> mcerr_t XntoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size);
> ```

Let `XnrtoYn` be the <i>analogous restartable transcoding function</i>. The transcoding functions behave as-if they:

- create an automatic storage duration object of `mbstate_t` type called `temporary_state`,
- initialize `temporary_state` to the initial conversion sequence by calling the analogous restartable transcoding function with `NULL` for `input` and `&temporary_state`, as-if by invoking `XnrtoYn(NULL, NULL, NULL, NULL, &temporary_state)`;
- call the function and saves the result as-if by invoking `mcerr_t err = XnrtoYn(input, input_size, output, output_size, &temporary_state);`; and,
- return `err`.

The interpretation of the values of the transcoding functions' parameters are identical meaning to the restartable transcoding functions' parameters.
</p></div>

<p><h5><b>7.S�.2 &emsp; Restartable and Non-Restartable Sized Multi Unit Conversion Functions</b></h5></p>

> ```c
> #include <stdmchar.h>
> 
> mcerr_t c8sntoc16sn(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size);
> mcerr_t c8snrtoc16sn(const unsigned char** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mcerr_t c8sntoc32sn(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size);
> mcerr_t c8snrtoc32sn(const unsigned char** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
> 
> mcerr_t c16sntoc8sn(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mcerr_t c16snrtoc8sn(const char16_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> mcerr_t c16sntoc32sn(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size);
> mcerr_t c16snrtoc32sn(const char16_t** input, size_t* input_size, char32_t** output, size_t* output_size, mbstate_t* state);
>
> mcerr_t c32sntoc16sn(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size);
> mcerr_t c32snrtoc16sn(const char32_t** input, size_t* input_size, char16_t** output, size_t* output_size, mbstate_t* state);
> mcerr_t c32sntoc8sn(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size);
> mcerr_t c32snrtoc8sn(const char32_t** input, size_t* input_size, unsigned char** output, size_t* output_size, mbstate_t* state);
> ```

<div class="wording-numbered"><p>
Let:
<ul>
	<li><i>transcoding function</i> be one of the functions listed above transcribed in the form `mcerr_t XsntoYsn(const charX** input, size_t* input_size, const charY** output, size_t* output_size)`;</li>
	<li><i>restartable transcoding function</i> be one of the functions listed above transcribed in the form `mcerr_t XnrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state)`;</li>
	<li><i>X</i> and <i>Y</i> be one of the prefixes from the table from 7.S�;</li>
	<li><i>`charX`</i> and <i>`charY`</i> be the associated code unit types for <i>X</i> and <i>Y</i> from the table from 7.S�; and</li>
	<li><i>encoding X</i> and <i>encoding Y</i> be the associated encoding types for <i>X</i> and <i>Y</i> from the table from 7.S�.</li>
</ul>

The transcoding functions and restartable transcoding functions take an input buffer and an output buffer of the associated code unit types, potentially with their sizes. The functions consume any number of code units to repeatedly perform a indivisible unit of work, which results in zero or more output code units. The functions will repeatedly perform an indivisible unit of work until either an error occurs or the input is exhausted.
</p></div>

<p><b>Constraints</b></p>
<div class="wording-numbered"><p>
On success or failure, the transcoding functions and restartable transcoding functions shall return one of the above error codes (7.S�). `state` shall not be `NULL`. If `state` is not initialized to the initial conversion sequence for the function, or is used after being input into a function whose result was not one of `MCHAR_OK`, `MCHAR_INSUFFICIENT_OUTPUT`, or `MCHAR_INCOMPLETE_INPUT`, then the behavior of the functions is unspecified. For the restartable transcoding functions, if `input` is `NULL`, then `*state` is set to the initial conversion sequence as described below and no other work is performed. Otherwise, for both restartable and non-restartable functions, `input` must not be `NULL` and `input_size` must not be `NULL`.
</p></div>

<p><b>Semantics</b></p>
<div class="wording-numbered"><p>
The restartable transcoding functions take the form:

> ```c
> mcerr_t XnsrtoYn(const charX** input, size_t* input_size, const charY** output, size_t* output_size, mbstate_t* state);
> ```

It converts from code units of type `charX` interpreted according to encoding X to code units of type `charY` according to encoding Y given a conversion state of value `*state`. The behavior of these functions is as-if the analogous single unit function `XnrtoYn` was repeatedly called, with the same `input`, `input_size`, `output`, `output_size`, and `state` parameters, to perform multiple indivisible units of work. The function stops when an error occurs or the input is empty (only signified by `*input_size` is zero).
</p></div>

<div class="wording-numbered"><p>
Let <i>indivisible work</i> be defined as performing the following:

- If `input` is `NULL`, then `*state` is set to the initial conversion sequence associated with encoding X. The function returns `MCHAR_OK`.
- If `input_size` is not `NULL`, then the function reads code units from `*input` if `*input_size` is large enough to produce an indivisible unit of work. If no encoding errors have occurred but the input is exhausted before an indivisible unit of work can be computed, the function returns `MCHAR_INCOMPLETE_INPUT`.
- If `input_size` is `NULL`, then `*input` is read that it points to a buffer of sufficient size and values. The behavior is undefined if the input buffer is not large enough.
- If `output` is `NULL`, then no output will be written.
- If `output_size` is not `NULL`, then `*output_size` will be decremented the amount of characters that would have been written to `*output` (even if `output` was `NULL`). If the output is exhausted (`*output_size` will be decremented below zero), the function returns `MCHAR_INSUFFICIENT_OUTPUT`.
- If `output_size` is `NULL` and output is not `NULL`, then enough space is assumed in the buffer pointed to by `*output` for the entire operation and the behavior is undefined if the output buffer is not large enough.

The behavior of the restartable transcoding functions is as follows.

- Evaluate indivisible work once.
- If the function has not yet returned and the input is not empty (`*input_size` is not zero), return to the first step.
- Otherwise, if the input is empty, return `MCHAR_OK`.
</p></div>

<div class="wording-numbered"><p>
The following is true after the invocation:

- `*input` will be incremented by the number of code units read and successfully converted. If `MCHAR_OK` is returned, then this will consume all the input. Otherwise, `*input` will point to the location just after the last successfully performed conversion.
- `*input_size` is decremented by the number of code units read from `*input` that were successfully converted. If no error occurred, then `*input_size` will be 0.
- if `output` is not `NULL`, `*output` will be incremented by the number of code units written.
- if `output_size` is not `NULL`, `*output_size` is decremented by the number of code units written to the output.

If the return value is `MCHAR_ENCODING_ERROR`, then `*state` is in an unspecified state.
</p></div>

<div class="wording-numbered"><p>
The non-restartable transcoding functions take the form:

> ```c
> mcerr_t XsntoYsn(const charX** input, size_t* input_size, const charY** output, size_t* output_size);
> ```

Let `XsnrtoYsn` be the <i>analogous restartable transcoding function</i>. The transcoding functions behave as-if they:

- create an automatic storage duration object of `mbstate_t` type called `temporary_state`,
- initialize `temporary_state` to the initial conversion sequence by calling the analogous restartable transcoding function with `NULL` for `input` and `&temporary_state`, as-if by invoking `XsnrtoYsn(NULL, NULL, NULL, NULL, &temporary_state)`;
- calls the analogous restartable transcoding function and saves the result as if by `mcerr_t err = XsnrtoYsn(input, input_size, output, output_size, &temporary_state);`; and,
- returns `err`.

The interpretation of the values of the transcoding functions' parameters are identical meaning to the restartable transcoding functions' parameters.
</p></div>
</ins>
</div>
</blockquote>




# Acknowledgements

Thank you to Shepherd.

<div class="pagebreak"></div>




# References

[^non-utf-functions]: JeanHeyd Meneide, Shepherd. Restartable and Non-Restartable Functions for Efficient Character Conversions | r4. December 2020. Published: [https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Efficient%20Character%20Conversions.html](https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Efficient%20Character%20Conversions.html).  