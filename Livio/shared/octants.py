"""2x4 octant glyph table - GENERATED, do not hand-edit.

Derived by sampling the outlines of CaskaydiaMono NF rather than transcribed from
the Unicode 16 charts: every codepoint that could plausibly be a solid sub-cell
block is probed at nine points per octant cell and kept only if each cell comes
out uniformly inside or outside, and only if its bounding box lands on the 2x4
grid. Both tests are needed - the shade characters pass a naive centre probe, and
LEFT THREE EIGHTHS BLOCK otherwise masquerades as a left half.

GLYPHS[pattern] is the character for a bitmask whose bit (row * 2 + col) is set
when that cell is filled, row 0 at the top. 230 of the 256 entries come from the
Unicode 16 octant block U+1CD00..U+1CDE5; the other 26 are space plus older block
elements (full block, the halves, quarters and quadrants, U+1FB82/1FB85,
U+1FBE6/1FBE7 and four corner eighths), preferred where they exist because font
coverage for them is much wider.

Requires a font with Symbols for Legacy Computing Supplement. CaskaydiaMono NF
carries all 230; Cascadia Mono, Cascadia Code and Ubuntu Mono carry none.
"""

GLYPHS = (
    "\U00000020\U0001cea8\U0001ceab\U0001fb82\U0001cd00\U00002598\U0001cd01\U0001cd02"
    "\U0001cd03\U0001cd04\U0000259d\U0001cd05\U0001cd06\U0001cd07\U0001cd08\U00002580"
    "\U0001cd09\U0001cd0a\U0001cd0b\U0001cd0c\U0001fbe6\U0001cd0d\U0001cd0e\U0001cd0f"
    "\U0001cd10\U0001cd11\U0001cd12\U0001cd13\U0001cd14\U0001cd15\U0001cd16\U0001cd17"
    "\U0001cd18\U0001cd19\U0001cd1a\U0001cd1b\U0001cd1c\U0001cd1d\U0001cd1e\U0001cd1f"
    "\U0001fbe7\U0001cd20\U0001cd21\U0001cd22\U0001cd23\U0001cd24\U0001cd25\U0001cd26"
    "\U0001cd27\U0001cd28\U0001cd29\U0001cd2a\U0001cd2b\U0001cd2c\U0001cd2d\U0001cd2e"
    "\U0001cd2f\U0001cd30\U0001cd31\U0001cd32\U0001cd33\U0001cd34\U0001cd35\U0001fb85"
    "\U0001cea3\U0001cd36\U0001cd37\U0001cd38\U0001cd39\U0001cd3a\U0001cd3b\U0001cd3c"
    "\U0001cd3d\U0001cd3e\U0001cd3f\U0001cd40\U0001cd41\U0001cd42\U0001cd43\U0001cd44"
    "\U00002596\U0001cd45\U0001cd46\U0001cd47\U0001cd48\U0000258c\U0001cd49\U0001cd4a"
    "\U0001cd4b\U0001cd4c\U0000259e\U0001cd4d\U0001cd4e\U0001cd4f\U0001cd50\U0000259b"
    "\U0001cd51\U0001cd52\U0001cd53\U0001cd54\U0001cd55\U0001cd56\U0001cd57\U0001cd58"
    "\U0001cd59\U0001cd5a\U0001cd5b\U0001cd5c\U0001cd5d\U0001cd5e\U0001cd5f\U0001cd60"
    "\U0001cd61\U0001cd62\U0001cd63\U0001cd64\U0001cd65\U0001cd66\U0001cd67\U0001cd68"
    "\U0001cd69\U0001cd6a\U0001cd6b\U0001cd6c\U0001cd6d\U0001cd6e\U0001cd6f\U0001cd70"
    "\U0001cea0\U0001cd71\U0001cd72\U0001cd73\U0001cd74\U0001cd75\U0001cd76\U0001cd77"
    "\U0001cd78\U0001cd79\U0001cd7a\U0001cd7b\U0001cd7c\U0001cd7d\U0001cd7e\U0001cd7f"
    "\U0001cd80\U0001cd81\U0001cd82\U0001cd83\U0001cd84\U0001cd85\U0001cd86\U0001cd87"
    "\U0001cd88\U0001cd89\U0001cd8a\U0001cd8b\U0001cd8c\U0001cd8d\U0001cd8e\U0001cd8f"
    "\U00002597\U0001cd90\U0001cd91\U0001cd92\U0001cd93\U0000259a\U0001cd94\U0001cd95"
    "\U0001cd96\U0001cd97\U00002590\U0001cd98\U0001cd99\U0001cd9a\U0001cd9b\U0000259c"
    "\U0001cd9c\U0001cd9d\U0001cd9e\U0001cd9f\U0001cda0\U0001cda1\U0001cda2\U0001cda3"
    "\U0001cda4\U0001cda5\U0001cda6\U0001cda7\U0001cda8\U0001cda9\U0001cdaa\U0001cdab"
    "\U00002582\U0001cdac\U0001cdad\U0001cdae\U0001cdaf\U0001cdb0\U0001cdb1\U0001cdb2"
    "\U0001cdb3\U0001cdb4\U0001cdb5\U0001cdb6\U0001cdb7\U0001cdb8\U0001cdb9\U0001cdba"
    "\U0001cdbb\U0001cdbc\U0001cdbd\U0001cdbe\U0001cdbf\U0001cdc0\U0001cdc1\U0001cdc2"
    "\U0001cdc3\U0001cdc4\U0001cdc5\U0001cdc6\U0001cdc7\U0001cdc8\U0001cdc9\U0001cdca"
    "\U0001cdcb\U0001cdcc\U0001cdcd\U0001cdce\U0001cdcf\U0001cdd0\U0001cdd1\U0001cdd2"
    "\U0001cdd3\U0001cdd4\U0001cdd5\U0001cdd6\U0001cdd7\U0001cdd8\U0001cdd9\U0001cdda"
    "\U00002584\U0001cddb\U0001cddc\U0001cddd\U0001cdde\U00002599\U0001cddf\U0001cde0"
    "\U0001cde1\U0001cde2\U0000259f\U0001cde3\U00002586\U0001cde4\U0001cde5\U00002588"
)
