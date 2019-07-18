---
title: [[nodiscard("should have a reason")]]
document: cXXX2
date: 2019-09-21
audience:
	- WG14
author:
	- name: JeanHeyd Meneide
	email: <phdofthehouse@gmail.com>
author:
	- name: Aaron Ballman
	email: <aaron@aaronballman.com>
author:
	- name: Isabella Muerte
	email: <https://twitter.com/slurpsmadrips>
---


# Introduction

Document N2051 introduced a new attribute `[[nodiscard]]` in the C2x working paper. This has provided a marked improvement in the marking of functions to remind programmers of the safety issues of discarding the return value of a function. The `[[nodiscard]]` attribute has helped prevent a serious class of software bugs, but sometimes it is hard to communicate exactly **why** a function is marked as `[[nodiscard]]` and perhaps what alternative usages are important.


This paper adds an addendum to allow a person to add a string attribute token to let someone provide a small reasoning or reminder for why a function has been marked `[[nodiscard("potential memory leak")]]`.



# Design Considerations

This paper is an enhancement of a preexisting feature to help programmers provide clarity with their code. Anything that makes the implementation warn or error should also provide some reasoning or perhaps point users to a knowledge base or similar to have any questions they have about the reason for the nodiscard attribute answered.

The design is very simple and follows the lead of the deprecated attribute. We propose allowing a string literal to be passed as an attribute argument clause, allowing for `[[nodiscard("use the returned token with lib_foobar")]]`. The key here is that there are some nodiscard attributes that have different kinds of "severity" versus others. That is, the cost of discarding vector::empty's return value is probably of slightly less concern than unique_ptr::release: one might manifest as a possible bug, the other is a downright memory leak.

Adding a reason to nodiscard allows implementers of the standard library, library developers, and application writers to benefit from a more clear and concise error beyond `"error:<line>: value marked [[nodiscard]] was discarded"`. This makes it easier for developers to understand the intent for return values for the used libraries.


# Proposed Wording

This proposed wording is currently relative to Working Paper N2385. The intent of this wording is to allow for the `[[nodiscard]]` attribute to be able to take a string literal.

## Changes

Add a second clause in §6.7.11.2 "The nodiscard attribute"'s **Constraint** subsection as follows:

> If an attribute argument clause is present, it shall have the form:
> 
> ( *string-literal* )

Add a third example after the first two in the **Recommended Practice** subsection as follows:

> ```
> [[nodiscard("must check armed state")]] 
> bool arm_detonator(int);
> 
> void call(void) {
>	arm_detonator(3);
>	detonate();
> }
> ```
> A diagnostic for the call to `arm_detonator` using the *string-literal* in the *attribute-argument-clause* is encouraged.
