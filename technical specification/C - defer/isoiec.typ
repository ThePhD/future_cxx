#import "@preview/based:0.1.0": base64

#let standard_iso9899_introduction_boilerplate = [This document is divided into four major subdivisions:

- preliminary elements (Clauses 1-4);
- the characteristics of environments that translate and execute C programs (Clause 5);
- the language syntax, constraints, and semantics (Clause 6);
- the library facilities (Clause 7).

In any given subsequent clause or subclause, there are section delineations in bold to describe the semantics, restrictions, and behaviors of programs for this language and potentially the use of its library clauses in this document:

- *Syntax* \
	which pertains to the spelling and organization of the language and library;
- *Constraints* \
	which detail and enumerate various requirements for the correct interpretation of the language and library, typically during translation;
- *Semantics* \
	which explain the behavior of language features and similar constructs;
- *Description* \
	which explain the behavior of library usage and similar constructs;
- *Returns* \
	which describes the effects of constructs provided back to a user of the library;
- *Recommended practice* \
	which provides guidance and important considerations for implementers of this document.

Examples are provided to illustrate possible forms of the constructions described. Footnotes are provided to emphasize consequences of the rules described in that subclause or elsewhere in this document. References are used to refer to other related subclauses. Recommendations are provided to give advice or guidance to implementers.]

#let iso_iec_logo_base64 = "iVBORw0KGgoAAAANSUhEUgAAAF4AAABYCAYAAAB8i0BzAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAABGxSURBVHhe7ZwHkBRlFsefLKCwgAISl5xBcpRwgoIBQVFhEREo5CyEU4JkqAOXJKCSM56ilEdZCpYcggiSC5AoQXKSKILk4C5Brn9vu5fZ2Z6Znt0Jq86/qmunp2enp//f+17+vvtat469KxGEHBnMvxGEGBHiw4QI8WFChPgwIUJ8mBAhPkyIEB8mRIgPEyLEhwl/isg1c+bMUrx4cSlTpowUKFBQ8ubNI/ff/4A8/PDDev3atWty48YNOXv2Vzlz5owcOnRYDh48oO+lV6Q74jNkyCD58uWTwoWLSNmyZaRcuXJSpEhRJd8dly5dklu3bknOnDklY8aM5rv3cPLkSTlw4IDs3btHjh8/LqdOndLPpwekG+IhvGLFSvLss02lWLHiki1bNsmUKZPcuXPHkN6DhhQfktq1axvSnlcuXrwoH3/8sfz881G9HhMTI6+91kkKFiyo37V06Xc6G8qVKy9Zs2aVP/74Q2fF2bNnZdmypbJ69Wq5eze8jx124nPkyKFS3bz5c6pKIPLXX39VUjdt2iw//bRT4uMTpGXLVvLiiy8a7/8sU6ZMVml2BYPUtWtXqVu3nvE/P8nEiRMkISFBya9du5bx3WUNNVXAUFH3y7lz5+SbbxbKtm3b9HU4BiFsxCPhdevWleeee95QJUXkvvvuk927d8u33y5Wci9cuJBESJMmTaRTp3+qqnj33ZEq8XZglrz9di+pUKGCLFz4P5k7d66+z3dnz55dZ0STJk9K/fr19X1IX778e1mwYIGehxJRjzzySJz5OiSABHR4x46vSatWrSQ6OlqJnj37Y/niiy/k9OnT8vvvv5ufFsmdO7eS/sADD8jMmTP0s55w8+ZN2bp1q9SrV09q1Kgh+/btVfUCkP7ffvvNmEWbZMOG9WoXGPDq1WuoCjtx4kSywQ42Qko8pD/++OPSpUtXKV++vPzyyy+qq7/88gs1fnYP3bJlSyVxzZrVhu5eqvraG27duilXr141CK0u+fMXkC1btuiAuILrW7dukT179ugAoOq4B68PHNgvt2/fNj8ZPISMeIxcmzZt5JVX2qqeXbFihbz33hiVNE8Pik7u1q27EjVq1CjHHgkqBOKLFSsm+/fvVxfTHQwgM2D9+nXGwCQYHlQ5w7hXVA8KL8h11gUDIQmg0K9vvvmWGlCkHgIhs1KlSoaUPaTvuQMb0KLFC3pt8eLFqiqcAtJQWxjcl15qafv9gPfR+9gM7AczjgEbOHCQGuVgIujGlek7dOgwdQOvX7+uhOKTu/rd6Fam+OHDR4zjsKGCThuDlUN69+4tWbJkkdGjRxuq6JgS46pqXF/zvQAyE48MEhcXJ6VKldKZhUuK8S1cuLC+V7JkKfWiGBzAdyMQzD7uyWCMGTNGvatgIKjE58qVS7p376E6dPPmzYY+/0hVTqFChdT3ZlrHxBQ0pC4m2UBAKBKOQYWMQ4cOGlIcryrhxo17KiA+PvF1hgxRSQEWRHLwv5CMP08Ey2BAqCsQBNzSU6dOqo3BsJ8795s0atRQZyezEoOO2xloBI14iBgz5j2dyvv27VM30JO6QFrRx0hgiRIl9HWhQoUlKipK/Xp3VeF+7gp3A23NBEg+ceK4HDt2TFMK+/fv03jBE2JjYzV2YDYOGzbU1k6kBUEhHsl6440u8uijj8qPP/6owUx8fLx51TeQ0okTJ6mRHD16lKoIJJj8TMaMUfraDpDOfW7fvqOz4/r1G9K+fXsd0LFjP9Df4hTco3Xr1kYk3cwYrJ9l3LhxXgfKXwTFq+HHNm3aVKWFB2bK+oMnnnhCqlWrpsHNDz/8oN+DP47uxwgitZ4OruOm8vlLly4aA5VJ/fQrV67Kjh3bzTv4Brp+165dKgRVq1bTGbhx40adgYFAwL2amjVryssvv6zGCaN2/vx584ozoF4qVaqsvjeRbFqxZctmJQtvxZuKsgO2Zt68eWpgiTuefPIp80raEVDiybsQkkP2nDmfeo0yPSExOZZR//fMmbRP7cuXL2s0y4ASBfsL1N2kSZN01jVu3DgpEZdWhC1X83dHSAKoCFIi3Uk87l90dDZD5URrasG9wIHux7fHe+EIRmiPV0a0jWfjWoDBVnB/cvs4DK4BnL/wSnyDBv9QvZZW8AO/+mq+V2NJxrJevfqa0n3ooYc00OKh0c2ugHQOYgLr8ITvvvvO8Io2mGfeQdBleHiGC1xXihYtollT3FcrsgU8B8QTkGE78JLWr1+vOR9/4ZV4Cg9t2rxinqUeuGYULzZsSE4CXkbJkiWlWbNmUqfOoylITis+/fRTWbx4kXlmjwcffFCqVKmiOR2Scv6CZ1u3bp3ex5/SYth0PNO4Q4cO0r//AJX0QJPuBFWqVJUBAwZqAi81pANUYcOGDWXIkHc0WHOdId4QFuKRdKLCpk2fVRc01MCOMMsGDRqkKYpAANX09NPPGJH2GFWbvhAW4olMn3rqab8DmkChRYsWxsC/bJ4FFiT/evToodlVbwg58aSJKeU5mZJWlhLPxTo491Q48QUGukGDBmq3POV70opEu1VK4uLeUa/ME7zmagiTablIKyCQWicpWIwouRNf0k5Gc/78ebJo0TfqnSxfvkKrVhs3/mB4EzvkyJGjOghMaysD6Q4+Rx7eAmnqzp3fcKTeSLhRHeM7tm/frnmgq1evqMflRGhy5HjQcHcTtAJmB69eTbVq1aVWrVrmWSI49/XDse4QZwHiV6xYbpB1RA1qs2bNzSv2IDzv1u0tR5INkZ5cXnevhvqtExXD7+V/6c/htSsYvD59+qhU+wKp5IEDB9h2tHmV+DNnftE8h+tRr15dQ13kMj9hDxJTs2bNTPofCgkkzZDyhg0baXXfGyhKLF++3DzzjtKly2gOhny7+7Fr186kfBHC8tZb3bxOfwBJ06ZNk1WrVqbI7QPUHUUdqlh58uQx37UHeacLF85rVc0dIdXxEO9kmpI/r1OnjnnmHfPmfSm9e/eyPegYs0APD9GoLyAomzZtNM/sceXKFe2OYHB9wVPNN6TEI0FOGkn5oUhnv379pHnz5joIZcuW1RIh5Ln6/Kgjokm7w1IT2ACntgppdpJzP3furKN6LDbBzmUNOfFMPScgXVCjRk1p1669tnhQ+R82bJh88MFYGTduvAZesbGttSXD1yzKmjU6qbPYF2hydQLyRNgsJ6CU6Y6Qu5P8WDvd6QmWerISV0hQ/vz5tbBBJ9rgwUNk5sxZ0qtXL+0gszP80dFZVd/6ArORqpVTUOlyAlrL3RFy4imneep9TC2IGnFTCf1pJaFs6Apmjy+jCjx1s3nC+fMXzFfekT17thR6PuTEM0XHjx8n1675V4d1AvImVIhQTXQNW+ChPfn6rrhzx7/AjGdxAuq+YSceoEc/+eQTx5k8f8EM6Ny5s/bzpFeEhXiwdu1aQy0M1cgODyTQIJ9PXwxqBu/GiaeSJUtW85UzUKxxAlpN3AOxsBEPWKdE38z7778nS5Z8G/CmITrJCHKsapUvkODyJz3ttHh++fIV89U9hJV4gCexc+dOmT17tvTo0d3w39+UqVOnaH5mz57dOhh0LRC0QJ675HgDHhBJOaJNynW+gAF26nais+m1cQIyAO4IO/HuoJ1izZo12meJKiICHTRooOnDvy+zZs3SnncngBySaAyu3cPbgdKjE6DK7PxzO7gm6iyEnHikCl/b7nAvbAMiU1b30feIK7py5QpVTXPn/tf8hHfwnbiIpAKcoHbtOo7SGqgxloD6QmJT7Cnz7B5CTvzzzz8vH374H9uDYrNTLF26zHzlHfRPAmuhmS/Qs0+nsDf3E9LpDfU1QKhF+vTt4DU7yfogFgfUrFkr6ShdurTPYITqPNJg/Q+hPxEhgRPkVqhgTzAqxE463IEKady4SYpAyR3MFvL5pJl5zSDQYujuU7sC40oaguiY7KZlU/ifxJxPRenTp6/PzCSg2fXzzz+3TW+HvMuA9udWrWLNK8mBSjhy5LAcPXpUe9UvXbqshhF/H+nKnDmTGsvy5Ss4yl5imEeMGJ4k6aQN+vXrrwk3J+De9M4jMAgTZPtTFJ8+fbqsXr3KNhpOV8S7gh+LtLn+aEvqvEmsK1atWiUzZkxP9h3M2BEjRppnwQP9NpMnT/LohaU7r8YC5DLtMY7WwblT0tnXgCYqd2nDw6B1HIMdLJDPnzZtqlfXN90SnxagGsaPH+9xIQE5d4hxmmvxB0j6jBkzfKZD/lLE3759S9sEx44d6zVXziygiN2/fz9d+BCInBFOAbEHq1+cVKb+EsRDJDmfCRPGq49PKsIJML5I/pAhg3UA3NWSExBVf/TRR2rEWQDtFF6NK6udyXOnFSSovv9+mRZ98ZMrV65sXkkOElq5cz9sNowmdgq7979AjpV7QaUcPnxIfXS8oNQQ5wr6KPGWcBkp6HNvV9eZ5+C+169f03YP1lQxw1JzX6/EhwuJriNrYTMZD558nxoMFtlMemr4m1ayPQHSOfgdFrg3xONmOsl2ekO6JP7vgL+kV/NnQECJJzLs27evESxN1V06UgP0LC3PI0e+q2F7IEC0ym9KzeIzQPMS/093g9O0sS8ElHhy3kuWLFHy2rZ9VXsv/QVLXBIS4jXlGgjiablj4QE2wd+ln4Df0LXrvzS3v2jRolSt/rBDwFUNqds5c+ao9Pfo0dNv8jBg27fvUI/Gk/fjD+j15Lu2b3e+qttCVFRGefXVdrr3Ah7M2rVrzCtpR1CMK95Ap06d5LHHGhru1k+Gfz3Br9XdSClTG+maMmWK9sVYXgZpA8vVdEVCAovSbmpeyHI32XiiXbt22smFf0/Q5BS4tO3bd1CVSXGezgiynIFC0LwaXMK4uKGqH/GxBw/+d4rym5X0IuPHRj30TCZuIFEoBbFpBVUo+maIaNlAAjKt/h47l5RNjV544UXN+VAJS42a8oagupPo+p49e2oad+fOHaqCCJCKFCks7CtJQSFfvryGdN3r8kLVQBISSwoYCWZ1HdLLNimcewrxM2e+35gRGYyZkUWyZEmsCeTJc2+fHPdtU0iUEb2eOHHMOE7qQd2ANnJav9kPgcjWteU8UAi6H09Jjz5HJB8Dh6pwzTISjBDusycNUshiAN7DmPF/TPlRo97VdmtLMj0FTdZ38peD9Ui0hA8fPlQ3IWKAmVFsJMoMI0VsVZr4Tgb17t0/dABpSqXOa20mF2iEJICiMPz6669L/foN9BzdTXs1RJNB5IHdASEdO3bUtVJsFjd//nzzijNQO2WHJ/agHD58mPlucqDOYmIKGTaguN4HW8AAJDZczXbclJoahCSAQnXQHfDZZ59pqI00sxUJA2BHOkDlLFy4UD//zDNNVfKdgs/GxrbSlMKCBV+b76YE9z59+pR2IliVJRYkY4iDSToI2S58PCRZQ9KnRYsWVR+/UaNGqn8ZALtuMgYM7cGSIMpuJMMYEF9ggRkrT9DN+N52NgHPiIRdly5ddAU7fTvsvopwoOqCjZARb4F2h82bN2nyicI3BWsK4hhP6pvu+hvjhz+Px4OeZ7Mgb2A29ez5thpSDCP/7w7WL7F2ikUPxBl79+6VyZMnq7Q7GdhAIOTEAzwWVtJhVJnmGEC20aLnHV8cI4zUMQh8lg3gSNdioAlkPBUa8KL69u2nZLJikP5MgL3AQ2JLQxa/sQKb0J/+dtov2OWVvQlCiZAYV29AH5cokbifAZKNN4LPjEqiRLdt21YlhV4Xdn7Cy5g0aWIKHUxwRaRctWpVjVLZ3AfCWYJTp05tw5sproOMQaU56uuvvzYM7y7tZAgHwk68BQjHq2AvM3a+RmWgh5n6uJisN2LLLKJa9DGeDlvUch0XsW3btuqzg5UrV6qxxF3EdcW+MHgMJs2xTrvKgol0Q7wFpBRyWb5SqlRJtQPMCDuvBuPLYgL8c8sft4BBxSawsTMqDdLR96HS4b6Q7oi3A7OBNELx4iW0lTpXrpzJ0rPYYyJOIlHSExDO4clVTQ/4UxD/V0RIAqgIUiJCfJgQIT5MiBAfJkSIDxMixIcJEeLDhAjxYUKE+LBA5P80VWYFezDaYAAAAABJRU5ErkJggg=="

#let iso_iec_logo = image.decode(base64.decode(iso_iec_logo_base64))

#let example_counter = counter("example")
#let example() = {
	example_counter.step()
	[EXAMPLE #context example_counter.display() #h(0.5em)]
}

#let note_counter = counter("note")
#let note() = {
	note_counter.step()
	[NOTE #context note_counter.display() #h(0.5em)]
}

#let wd_stage = 1

#let isoiec(
	title: none,
	authors: (),
	keywords: (),
	header: none,
	footer: none,
	abstract: none,
	intro: none,
	id: "NXYZW",
	ts_id: "ABCD",
	stage: none,
	no_boilerplate: false,
	contents
) = {
if stage == none {
	stage = "wd"
}
let stage_enum = if stage == "wd" or stage == "working draft" { 0 }
else if stage == "cd" or stage == "committee draft" { 1 }
else if stage == "dis" or stage == "draft international stage" { 2 }
else if stage == "publication" { 3 } else { none }
// general page settings, header/footer, initial settings
// and styling
set document(title: title, author: authors, keywords: keywords)
set page(
	paper: "a4",
	header: context {
		if here().position().page == 1 {
			// no header on first page
		} else {
			align(center)[
				#if header != none [
					#header
				] else [
					ISO/DIS TS#ts_id\(#context text.lang)
				]
			]
		}
	},
	footer: context {
		let pagenum = here().position().page
		if pagenum == 1 or pagenum == counter(page).final().at(0) {
			// no header on first page
		} else {
			align(center)[
				#if footer != none [
					#footer
				] else [
					© ISO #datetime.today().year() — All rights reserved. \
					#counter(page).display(here().page-numbering())
				]
			]
		}
	},
	numbering: "i",
)
set raw(tab-size: 5, syntaxes: ("isoc.sublime-syntax"), theme: "isoc.tmTheme")
show raw.where(block: false): code => {
	show regex("\b(defer)\b"): keyword => text(weight:"bold", keyword)
	code
}
show raw.where(block: true): code => {
	show regex("\b(defer)\b"): keyword => text(weight:"bold", keyword)
	pad(left: 2%, right: 2%,
		block(
			fill: rgb("#fcfcfc"),
			stroke: 0.5pt + rgb("#000000"),
			inset: 1.0em,
			radius: 0pt,
			width: 96%,
			code
		)
	)
}

set heading(numbering: none)
show heading: it => {
	if it.numbering != none and counter(heading).get().at(0) > 0 {
		let number = if it.numbering != none {
			numbering(it.numbering, ..counter(heading).at(it.location()))
		}
		else {
			counter(heading).display()
		}
		box(width: 1.5cm, number)
	}
	it.body
}

set list(marker: ("—","—","—"), indent: 2.0em)

show outline.entry: entry => {
	if entry.level == 1 {
		// Vertical spacing between top-level headings
		v(2em, weak: true)
	}
	if entry.element.func() == heading {
		let elem = entry.element
		let number = if elem.numbering != none {
			numbering(elem.numbering, ..counter(heading).at(elem.location()))
		}
		let fill = box(width: 1fr, entry.fill)
		let entry_content = [#box(width: 2em, [#number])#elem.body #fill #entry.page]
		if entry.level == 1 {
			strong(entry_content)
		}
		else {
			entry_content
		}
	}
	else {
		entry
	}
}

// Cover page
// four-line cell barriers with custom empty spaces
place(top, line(start: (62%, 0%), end: (62%, 39%), stroke: 0.5pt + rgb("#000000")))
place(top, line(start: (62%, 41%), end: (62%, 100%), stroke: 0.5pt + rgb("#000000")))
place(top, line(start: (0%, 40%), end: (61%, 40%), stroke: 0.5pt + rgb("#000000")))
place(top, line(start: (63%, 40%), end: (100%, 40%), stroke: 0.5pt + rgb("#000000")))
grid(columns: (60%, 36%), rows: (38%, 53%, 1%),
column-gutter: 4%, row-gutter: 4%,
inset: 0.5em,
[#iso_iec_logo],
[
#set text(size: 1.5em, weight: "bold")
#if stage != "published" [DRAFT\ ]
Technical\
Specification

#align(bottom, [ISO/DIS TS #ts_id])
],
[
#align(top, text(weight: "bold", title))

#align(horizon, block(stroke: 0.5pt + rgb("#000000"), inset: 0.4em, text(size: 0.75em, [This document has not been edited by the ISO Central Secretariat.])))

#align(bottom, [
	Reference Number \
	ISO/DIS TS #ts_id #if stage != "published" [: Working Draft #id] else if stage_enum == 1 [: Committee Draft #id] else if stage_enum == 2 [: Draft International Standard #id]
])
],
[ISO/ TC22/SC22 \
Secretariat: JISC

Voting begins on: n/a
#v(2.5em)
Voting terminates on: n/a
#v(2.5em)

#set align(bottom)
#if stage != "published" [
#set text(size: 0.7em)
THIS DOCUMENT IS A DRAFT CIRCULATED FOR COMMENTS AND APPROVAL. IT IS THEREFORE SUBJECT TO CHANGE AND MAY NOT BE REFERRED TO AS A TECHNICAL SPECIFICATION UNTIL PUBLISHED AS SUCH.

IN ADDITION TO THEIR EVALUATION AS BEING ACCEPTABLE FOR INDUSTRIAL, TECHNOLOGICAL, COMMERCIAL AND USER PURPOSES, DRAFT TECHNICAL SPECIFICATIONS MAY ON OCCASION HAVE TO BE CONSIDERED IN THE LIGHT OF THEIR POTENTIAL TO BECOME STANDARDS TO WHICH REFERENCE MAY BE MADE IN NATIONAL REGULATIONS.

RECIPIENTS OF THIS DRAFT ARE INVITED TO SUBMIT, WITH THEIR COMMENTS, NOTIFICATION OF ANY RELEVANT PATENT RIGHTS OF WHICH THEY ARE AWARE AND TO PROVIDE SUPPORTING DOCUMENTATION.]

#v(1.0em)

© ISO #datetime.today().year()
]
)
// No pagebreak necessary because the grid takes up all the space!
pagebreak()

// Copyright Page
align(bottom)[
#text(2.0em)[⚠ COPYRIGHT PROTECTED DOCUMENT]<copyright>


© ISO/IEC #datetime.today().year() \
All rights reserved. Unless otherwise specified, no part of this publication may be reproduced or utilized otherwise in any form or by any means, electronic or mechanical, including photocopying, or posting on the internet or an intranet, without prior written permission. Permission can be requested from either ISO at the address below or ISO's member body in the country of the requester.

ISO copyright office \
Case postale 56 • CH-1211 Geneva 20 \
#link("tel:+41227490111")[Tel. + 41 22 749 01 11] \
#link("tel:+41227490947")[Fax + 41 22 749 09 47] \
E-mail #link("mailto:copyright@iso.org") \
Web #link("https://www.iso.org")[www.iso.org] \

Published in Switzerland \
\
]
pagebreak()

// table of contents
outline(depth: 3, indent:{2em}, title: "Content")
pagebreak()

// Foreword Boilerplate
[= Foreword <foreword>

ISO (the International Organization for Standardization) and IEC (the International Electrotechnical Commission) form the specialized system for worldwide standardization. National bodies that are members of ISO or IEC participate in the development of International Standards through technical committees established by the respective organization to deal with particular fields of technical activity. ISO and IEC technical committees collaborate in fields of mutual interest. Other international organizations, governmental and non-governmental, in liaison with ISO and IEC, also take part in the work.

The procedures used to develop this document and those intended for its further maintenance are described in the ISO/IEC Directives, Part 1. In particular, the different approval criteria needed for the different types of document should be noted. This document was drafted in accordance with the editorial rules of the ISO/IEC Directives, Part 2 (see #link("https://www.iso.org/directives")[www.iso.org/directives] or #link("https://www.iec.ch/members_experts/refdocs")[www.iec.ch/members_experts/refdocs]).

ISO and IEC draw attention to the possibility that the implementation of this document may involve the use of (a) patent(s). ISO and IEC take no position concerning the evidence, validity or applicability of any claimed patent rights in respect thereof. As of the date of publication of this document, ISO and IEC had not received notice of (a) patent(s) which may be required to implement this document. However, implementers are cautioned that this may not represent the latest information, which may be obtained from the patent database available at #link("https://www.iso.org/patents")[www.iso.org/patents] and #link("https://patents.iec.ch")[patents.iec.ch]. ISO and IEC shall not be held responsible for identifying any or all such patent rights.

Any trade name used in this document is information given for the convenience of users and does not constitute an endorsement.

For an explanation of the voluntary nature of standards, the meaning of ISO specific terms and expressions related to conformity assessment, as well as information about ISO's adherence to the World Trade Organization (WTO) principles in the Technical Barriers to Trade (TBT) see #link("https://www.iso.org/iso/foreword.html")[www.iso.org/iso/foreword.html]. In the IEC, see #link("https://www.iec.ch/understanding-standards")[www.iec.ch/understanding-standards].

This document was prepared by Joint Technical Committee ISO/IEC JTC 1, Information technology, Subcommittee SC 22, Programming languages, their environments and system software interfaces.

Any feedback or questions on this document should be directed to the user's national standards body. A complete listing of these bodies can be found at #link("https://www.iso.org/members.html")[www.iso.org/members.html] and #link("https://www.iec.ch/national-committees")[www.iec.ch/national-committees].]
pagebreak()

// Introduction: ignored if there is no provided introduction.
if intro != none [
= Introduction <intro>

#intro
#pagebreak()
] else if abstract != none [
= Introduction <intro>

#abstract

#standard_iso9899_introduction_boilerplate
#pagebreak()
] else {
	if not no_boilerplate [
		= Introduction <intro>

		#standard_iso9899_introduction_boilerplate
		#pagebreak()
	]
}

// Rest of the document
set page(numbering: "1")
set par(justify: true)
set heading(outlined: true, bookmarked: true, numbering: "1.1.1.1")
contents
pagebreak()

// Last page
// four-line cell barriers with custom empty spaces
place(top, line(start: (62%, 0%), end: (62%, 39%), stroke: 0.5pt + rgb("#000000")))
place(top, line(start: (62%, 41%), end: (62%, 100%), stroke: 0.5pt + rgb("#000000")))
place(top, line(start: (0%, 40%), end: (61%, 40%), stroke: 0.5pt + rgb("#000000")))
place(top, line(start: (63%, 40%), end: (100%, 40%), stroke: 0.5pt + rgb("#000000")))
grid(columns: (60%, 36%), rows: (38%, 53%, 1%),
column-gutter: 4%, row-gutter: 4%,
inset: 0.5em,
[#iso_iec_logo],
[],
align(bottom, [© ISO #datetime.today().year() - All rights reserved]),
align(bottom + right, link("https://www.iso.org")[www.iso.org])
)
}
