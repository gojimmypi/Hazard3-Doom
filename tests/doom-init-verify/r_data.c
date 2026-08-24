//
// Copyright(C) 1993-1996 Id Software, Inc.
// Copyright(C) 2005-2014 Simon Howard
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//	Preparation of data for rendering,
//	generation of lookups, caching, retrieval by name.
//

#include <stdio.h>
#include <stddef.h>
#include <string.h>

#include "deh_main.h"
#include "i_swap.h"
#include "i_system.h"
#include "z_zone.h"


#include "w_wad.h"

#include "doomdef.h"
#include "m_misc.h"
#include "r_local.h"
#include "p_local.h"

#include "doomstat.h"
#include "r_sky.h"


#include "r_data.h"

//
// Graphics.
// DOOM graphics for walls and sprites
// is stored in vertical runs of opaque pixels (posts).
// A column is composed of zero or more posts,
// a patch or sprite is composed of zero or more columns.
// 



//
// Texture definition.
// Each texture is composed of one or more patches,
// with patches being lumps stored in the WAD.
// The lumps are referenced by number, and patched
// into the rectangular texture space using origin
// and possibly other attributes.
//
typedef struct
{
    short	originx;
    short	originy;
    short	patch;
    short	stepdir;
    short	colormap;
} PACKEDATTR mappatch_t;


//
// Texture definition.
// A DOOM wall texture is a list of patches
// which are to be combined in a predefined order.
//
typedef struct
{
    char		name[8];
    int			masked;	
    short		width;
    short		height;
    int                 obsolete;
    short		patchcount;
    mappatch_t	patches[1];
} PACKEDATTR maptexture_t;


// A single patch from a texture definition,
//  basically a rectangular area within
//  the texture rectangle.
typedef struct
{
    // Block origin (allways UL),
    // which has allready accounted
    // for the internal origin of the patch.
    short	originx;	
    short	originy;
    int		patch;
} texpatch_t;


// A maptexturedef_t describes a rectangular texture,
//  which is composed of one or more mappatch_t structures
//  that arrange graphic patches.

typedef struct texture_s texture_t;

struct texture_s
{
    // Keep name for switch changing, etc.
    char	name[8];		
    short	width;
    short	height;

    // Index in textures list

    int         index;

    // Next in hash table chain

    texture_t  *next;
    
    // All the patches[patchcount]
    //  are drawn back to front into the cached texture.
    short	patchcount;
    texpatch_t	patches[1];		
};



int		firstflat;
int		lastflat;
int		numflats;

int		firstpatch;
int		lastpatch;
int		numpatches;

int		firstspritelump;
int		lastspritelump;
int		numspritelumps;

int		numtextures;
texture_t**	textures;
texture_t**     textures_hashtable;


int*			texturewidthmask;
// needed for texture pegging
fixed_t*		textureheight;		
int*			texturecompositesize;
short**			texturecolumnlump;
unsigned short**	texturecolumnofs;
byte**			texturecomposite;

// for global animation
int*		flattranslation;
int*		texturetranslation;

// needed for pre rendering
fixed_t*	spritewidth;	
fixed_t*	spriteoffset;
fixed_t*	spritetopoffset;

lighttable_t	*colormaps;


/*
 * H3DIV: Doom initialization verifier.
 *
 * All verifier storage is static image BSS. It does not consume Doom Zone
 * memory, so the allocator order used by R_InitTextures remains unchanged.
 */
#define H3DIV_MAX_TEXTURES       256
#define H3DIV_MAX_PNAMES_BYTES  4096
#define H3DIV_MAX_TEXTURE_BYTES 16384

#define H3DIV_DOOM1_PNAMES_SIZE       2804u
#define H3DIV_DOOM1_PNAMES_FNV1A      0x70dcd40au
#define H3DIV_DOOM1_TEXTURE1_SIZE     9234u
#define H3DIV_DOOM1_TEXTURE1_FNV1A    0x7bfce9c1u

static byte h3div_pnames_shadow[H3DIV_MAX_PNAMES_BYTES] __attribute__((aligned(4)));
static byte h3div_texture_shadow[H3DIV_MAX_TEXTURE_BYTES] __attribute__((aligned(4)));
static texture_t *h3div_texture_ptr[H3DIV_MAX_TEXTURES];
static unsigned int h3div_texture_hash[H3DIV_MAX_TEXTURES];
static unsigned int h3div_raw_hash[H3DIV_MAX_TEXTURES];
static unsigned int h3div_raw_offset[H3DIV_MAX_TEXTURES];
static char h3div_texture_name[H3DIV_MAX_TEXTURES][9];
static short h3div_texture_width[H3DIV_MAX_TEXTURES];
static short h3div_texture_height[H3DIV_MAX_TEXTURES];
static short h3div_texture_patchcount[H3DIV_MAX_TEXTURES];
static int h3div_recorded_textures;

static unsigned int H3DIV_Fnv1a(const void *data, unsigned int size)
{
    const byte *p = (const byte *)data;
    unsigned int hash = 2166136261u;

    while (size-- != 0u)
    {
        hash ^= *p++;
        hash *= 16777619u;
    }

    return hash;
}


static unsigned int H3DIV_FirstMismatch(const byte *actual,
                                        const byte *expected,
                                        unsigned int size)
{
    unsigned int index;

    for (index = 0u; index < size; ++index)
    {
        if (actual[index] != expected[index])
        {
            return index;
        }
    }

    return size;
}

static void H3DIV_ByteCopy(byte *destination, const byte *source,
                           unsigned int size)
{
    volatile byte *volatile_destination = (volatile byte *)destination;
    unsigned int index;

    for (index = 0u; index < size; ++index)
    {
        volatile_destination[index] = source[index];
    }
}

static void H3DIV_PrintCopyResult(const char *name, const byte *actual,
                                  const byte *expected, unsigned int size)
{
    unsigned int actual_hash = H3DIV_Fnv1a(actual, size);
    unsigned int expected_hash = H3DIV_Fnv1a(expected, size);
    unsigned int first = H3DIV_FirstMismatch(actual, expected, size);

    printf("H3DIV copy %s: %s hash=%08x expected=%08x",
           name, first == size ? "PASS" : "FAIL",
           actual_hash, expected_hash);

    if (first != size)
    {
        printf(" first=%u actual=%02x expected_byte=%02x",
               first, actual[first], expected[first]);
    }

    printf("\n");
}
static unsigned int H3DIV_TextureHash(const texture_t *texture)
{
    unsigned int hash = H3DIV_Fnv1a(texture->name, 8);
    int i;

    hash ^= (unsigned short)texture->width;
    hash *= 16777619u;
    hash ^= (unsigned short)texture->height;
    hash *= 16777619u;
    hash ^= (unsigned short)texture->patchcount;
    hash *= 16777619u;

    for (i = 0; i < texture->patchcount; ++i)
    {
        hash ^= (unsigned short)texture->patches[i].originx;
        hash *= 16777619u;
        hash ^= (unsigned short)texture->patches[i].originy;
        hash *= 16777619u;
        hash ^= (unsigned int)texture->patches[i].patch;
        hash *= 16777619u;
    }

    return hash;
}

static unsigned int H3DIV_MapTextureBytes(const maptexture_t *texture)
{
    int patchcount = SHORT(texture->patchcount);

    if (patchcount <= 0 || patchcount > 1024)
    {
        I_Error("H3DIV FAIL stage=raw-patchcount name=%.8s patchcount=%i",
                texture->name, patchcount);
    }

    return (unsigned int)offsetof(maptexture_t, patches)
         + (unsigned int)patchcount * (unsigned int)sizeof(mappatch_t);
}

static void H3DIV_VerifyDoom1Reference(const char *name,
                                      const void *data,
                                      unsigned int size)
{
    unsigned int actual = H3DIV_Fnv1a(data, size);
    unsigned int expected = 0u;

    if (size == H3DIV_DOOM1_PNAMES_SIZE &&
        !strncmp(name, "PNAMES", 8))
    {
        expected = H3DIV_DOOM1_PNAMES_FNV1A;
    }
    else if (size == H3DIV_DOOM1_TEXTURE1_SIZE &&
             !strncmp(name, "TEXTURE1", 8))
    {
        expected = H3DIV_DOOM1_TEXTURE1_FNV1A;
    }

    if (expected != 0u && actual != expected)
    {
        I_Error("H3DIV FAIL stage=known-wad-hash lump=%s bytes=%u expected=%08x actual=%08x",
                name, size, expected, actual);
    }

    printf("H3DIV lump %s: PASS bytes=%u fnv1a=%08x%s\n",
           name, size, actual, expected != 0u ? " reference=DOOM1" : "");
}

static void H3DIV_VerifyTextureObject(int texnum, const char *stage)
{
    texture_t *texture;
    unsigned int actual_hash;
    int alias = -1;
    int i;

    if (texnum < 0 || texnum >= h3div_recorded_textures)
    {
        I_Error("H3DIV FAIL stage=%s bad-texnum=%i recorded=%i",
                stage, texnum, h3div_recorded_textures);
    }

    texture = textures[texnum];

    if (texture != h3div_texture_ptr[texnum])
    {
        for (i = 0; i < h3div_recorded_textures; ++i)
        {
            if (texture == h3div_texture_ptr[i])
            {
                alias = i;
                break;
            }
        }

        I_Error("H3DIV FAIL stage=%s tex=%i expected=%.8s expected_ptr=%p actual_ptr=%p aliases_tex=%i",
                stage, texnum, h3div_texture_name[texnum],
                h3div_texture_ptr[texnum], texture, alias);
    }

    if (memcmp(texture->name, h3div_texture_name[texnum], 8) != 0 ||
        texture->width != h3div_texture_width[texnum] ||
        texture->height != h3div_texture_height[texnum] ||
        texture->patchcount != h3div_texture_patchcount[texnum])
    {
        I_Error("H3DIV FAIL stage=%s tex=%i expected=%.8s %ix%i p=%i actual=%.8s %ix%i p=%i",
                stage, texnum, h3div_texture_name[texnum],
                h3div_texture_width[texnum], h3div_texture_height[texnum],
                h3div_texture_patchcount[texnum], texture->name,
                texture->width, texture->height, texture->patchcount);
    }

    actual_hash = H3DIV_TextureHash(texture);

    if (actual_hash != h3div_texture_hash[texnum])
    {
        I_Error("H3DIV FAIL stage=%s tex=%i name=%.8s expected_hash=%08x actual_hash=%08x",
                stage, texnum, h3div_texture_name[texnum],
                h3div_texture_hash[texnum], actual_hash);
    }
}


//
// MAPTEXTURE_T CACHING
// When a texture is first needed,
//  it counts the number of composite columns
//  required in the texture and allocates space
//  for a column directory and any new columns.
// The directory will simply point inside other patches
//  if there is only one patch in a given column,
//  but any columns with multiple patches
//  will have new column_ts generated.
//



//
// R_DrawColumnInCache
// Clip and draw a column
//  from a patch into a cached post.
//
void
R_DrawColumnInCache
( column_t*	patch,
  byte*		cache,
  int		originy,
  int		cacheheight )
{
    int		count;
    int		position;
    byte*	source;

    while (patch->topdelta != 0xff)
    {
	source = (byte *)patch + 3;
	count = patch->length;
	position = originy + patch->topdelta;

	if (position < 0)
	{
	    count += position;
	    position = 0;
	}

	if (position + count > cacheheight)
	    count = cacheheight - position;

	if (count > 0)
	    memcpy (cache + position, source, count);
		
	patch = (column_t *)(  (byte *)patch + patch->length + 4); 
    }
}



//
// R_GenerateComposite
// Using the texture definition,
//  the composite texture is created from the patches,
//  and each column is cached.
//
void R_GenerateComposite (int texnum)
{
    byte*		block;
    texture_t*		texture;
    texpatch_t*		patch;	
    patch_t*		realpatch;
    int			x;
    int			x1;
    int			x2;
    int			i;
    column_t*		patchcol;
    short*		collump;
    unsigned short*	colofs;
	
    texture = textures[texnum];

    block = Z_Malloc (texturecompositesize[texnum],
		      PU_STATIC, 
		      &texturecomposite[texnum]);	

    collump = texturecolumnlump[texnum];
    colofs = texturecolumnofs[texnum];
    
    // Composite the columns together.
    patch = texture->patches;
		
    for (i=0 , patch = texture->patches;
	 i<texture->patchcount;
	 i++, patch++)
    {
	realpatch = W_CacheLumpNum (patch->patch, PU_CACHE);
	x1 = patch->originx;
	x2 = x1 + SHORT(realpatch->width);

	if (x1<0)
	    x = 0;
	else
	    x = x1;
	
	if (x2 > texture->width)
	    x2 = texture->width;

	for ( ; x<x2 ; x++)
	{
	    // Column does not have multiple patches?
	    if (collump[x] >= 0)
		continue;
	    
	    patchcol = (column_t *)((byte *)realpatch
				    + LONG(realpatch->columnofs[x-x1]));
	    R_DrawColumnInCache (patchcol,
				 block + colofs[x],
				 patch->originy,
				 texture->height);
	}
						
    }

    // Now that the texture has been built in column cache,
    //  it is purgable from zone memory.
    Z_ChangeTag (block, PU_CACHE);
}



//
// R_GenerateLookup
//
void R_GenerateLookup (int texnum)
{
    texture_t*		texture;
    byte*		patchcount;
    texpatch_t*		patch;
    patch_t*		realpatch;
    int			x;
    int			x1;
    int			x2;
    int			i;
    short*		collump;
    unsigned short*	colofs;
    unsigned int        composite_columns = 0u;

    H3DIV_VerifyTextureObject(texnum, "lookup-entry");
    texture = textures[texnum];

    texturecomposite[texnum] = 0;
    texturecompositesize[texnum] = 0;

    if (texturecompositesize[texnum] != 0)
    {
        I_Error("H3DIV FAIL stage=composite-zero tex=%i name=%.8s actual=%08x",
                texnum, texture->name,
                (unsigned int)texturecompositesize[texnum]);
    }

    collump = texturecolumnlump[texnum];
    colofs = texturecolumnofs[texnum];

    patchcount = (byte *) Z_Malloc(texture->width, PU_STATIC, &patchcount);
    memset (patchcount, 0, texture->width);

    for (i=0 , patch = texture->patches;
         i<texture->patchcount;
         i++, patch++)
    {
        H3DIV_VerifyTextureObject(texnum, "lookup-pre-cache");
        realpatch = W_CacheLumpNum (patch->patch, PU_CACHE);
        H3DIV_VerifyTextureObject(texnum, "lookup-post-cache");

        if (texturecompositesize[texnum] != 0)
        {
            I_Error("H3DIV FAIL stage=composite-mutated-during-cache tex=%i patch=%i actual=%08x",
                    texnum, i, (unsigned int)texturecompositesize[texnum]);
        }

        x1 = patch->originx;
        x2 = x1 + SHORT(realpatch->width);

        if (x1 < 0)
            x = 0;
        else
            x = x1;

        if (x2 > texture->width)
            x2 = texture->width;

        for ( ; x<x2 ; x++)
        {
            patchcount[x]++;
            collump[x] = patch->patch;
            colofs[x] = LONG(realpatch->columnofs[x-x1])+3;
        }
    }

    H3DIV_VerifyTextureObject(texnum, "lookup-before-scan");

    if (texturecompositesize[texnum] != 0)
    {
        I_Error("H3DIV FAIL stage=composite-mutated-before-scan tex=%i name=%.8s actual=%08x",
                texnum, texture->name,
                (unsigned int)texturecompositesize[texnum]);
    }

    for (x=0 ; x<texture->width ; x++)
    {
        if (!patchcount[x])
        {
            I_Error("H3DIV FAIL stage=column-uncovered tex=%i name=%.8s x=%i width=%i",
                    texnum, texture->name, x, texture->width);
        }

        if (patchcount[x] > 1)
        {
            unsigned int expected_size =
                composite_columns *
                (unsigned int)(unsigned short)texture->height;

            if ((unsigned int)texturecompositesize[texnum] != expected_size)
            {
                I_Error("H3DIV FAIL stage=composite-pre tex=%i name=%.8s x=%i expected=%08x actual=%08x columns=%u",
                        texnum, texture->name, x, expected_size,
                        (unsigned int)texturecompositesize[texnum],
                        composite_columns);
            }

            collump[x] = -1;
            colofs[x] = texturecompositesize[texnum];

            if (texturecompositesize[texnum] >
                0x10000-texture->height)
            {
                I_Error("H3DIV FAIL stage=composite-overflow tex=%i name=%.8s x=%i size=%08x height=%i columns=%u",
                        texnum, texture->name, x,
                        (unsigned int)texturecompositesize[texnum],
                        texture->height, composite_columns);
            }

            texturecompositesize[texnum] += texture->height;
            ++composite_columns;

            if ((unsigned int)texturecompositesize[texnum] !=
                composite_columns *
                (unsigned int)(unsigned short)texture->height)
            {
                I_Error("H3DIV FAIL stage=composite-post tex=%i name=%.8s x=%i actual=%08x columns=%u",
                        texnum, texture->name, x,
                        (unsigned int)texturecompositesize[texnum],
                        composite_columns);
            }
        }
    }

    H3DIV_VerifyTextureObject(texnum, "lookup-exit");
    Z_Free(patchcount);
}



//
// R_GetColumn
//
byte*
R_GetColumn
( int		tex,
  int		col )
{
    int		lump;
    int		ofs;
	
    col &= texturewidthmask[tex];
    lump = texturecolumnlump[tex][col];
    ofs = texturecolumnofs[tex][col];
    
    if (lump > 0)
	return (byte *)W_CacheLumpNum(lump,PU_CACHE)+ofs;

    if (!texturecomposite[tex])
	R_GenerateComposite (tex);

    return texturecomposite[tex] + ofs;
}


static void GenerateTextureHashTable(void)
{
    texture_t **rover;
    int i;
    int key;

    textures_hashtable 
            = Z_Malloc(sizeof(texture_t *) * numtextures, PU_STATIC, 0);

    memset(textures_hashtable, 0, sizeof(texture_t *) * numtextures);

    // Add all textures to hash table

    for (i=0; i<numtextures; ++i)
    {
        // Store index

        textures[i]->index = i;

        // Vanilla Doom does a linear search of the texures array
        // and stops at the first entry it finds.  If there are two
        // entries with the same name, the first one in the array
        // wins. The new entry must therefore be added at the end
        // of the hash chain, so that earlier entries win.

        key = W_LumpNameHash(textures[i]->name) % numtextures;

        rover = &textures_hashtable[key];

        while (*rover != NULL)
        {
            rover = &(*rover)->next;
        }

        // Hook into hash table

        textures[i]->next = NULL;
        *rover = textures[i];
    }
}


//
// R_InitTextures
// Initializes the texture list
//  with the textures from the world map.
//
void R_InitTextures (void)
{
    maptexture_t*	mtexture;
    texture_t*		texture;
    mappatch_t*		mpatch;
    texpatch_t*		patch;

    int			i;
    int			j;

    int*		maptex;
    int*		maptex2;
    int*		maptex1;

    char		name[9];
    char*		names;
    char*		name_p;

    int*		patchlookup;

    int			totalwidth;
    int			nummappatches;
    int			offset;
    int			maxoff;
    int			maxoff2;
    int			numtextures1;
    int			numtextures2;

    int*		directory;

    int			temp1;
    int			temp2;
    int			temp3;
    int                 pnames_lump;
    int                 pnames_bytes;
    int                 texture1_lump;
    int                 texture1_bytes;

    name[8] = 0;

    /*
     * Verify PNAMES through Doom's real WAD path. The second read goes into
     * static image BSS, so this adds no Zone allocation and does not perturb
     * the heap layout used by R_InitTextures.
     */
    pnames_lump = W_GetNumForName(DEH_String("PNAMES"));
    pnames_bytes = W_LumpLength(pnames_lump);

    if (pnames_bytes <= 0 || pnames_bytes > H3DIV_MAX_PNAMES_BYTES)
    {
        I_Error("H3DIV FAIL stage=pnames-size bytes=%i max=%i",
                pnames_bytes, H3DIV_MAX_PNAMES_BYTES);
    }

    names = W_CacheLumpNum(pnames_lump, PU_STATIC);
    W_ReadLump((unsigned int)pnames_lump, h3div_pnames_shadow);

    if (memcmp(names, h3div_pnames_shadow, (size_t)pnames_bytes) != 0)
    {
        I_Error("H3DIV FAIL stage=pnames-cache-copy bytes=%i cached=%08x reread=%08x",
                pnames_bytes,
                H3DIV_Fnv1a(names, (unsigned int)pnames_bytes),
                H3DIV_Fnv1a(h3div_pnames_shadow,
                            (unsigned int)pnames_bytes));
    }

    H3DIV_VerifyDoom1Reference("PNAMES", names, (unsigned int)pnames_bytes);

    nummappatches = LONG(*((int *)names));
    name_p = names + 4;
    patchlookup = Z_Malloc(nummappatches*sizeof(*patchlookup),
                           PU_STATIC, NULL);

    for (i = 0; i < nummappatches; i++)
    {
        M_StringCopy(name, name_p + i * 8, sizeof(name));
        patchlookup[i] = W_CheckNumForName(name);
    }

    W_ReleaseLumpName(DEH_String("PNAMES"));

    /*
     * Cache TEXTURE1 exactly as stock Doom does, then independently reread it
     * into static BSS. This separates a bad cache/read copy from corruption
     * that occurs later while texture objects are being constructed.
     */
    texture1_lump = W_GetNumForName(DEH_String("TEXTURE1"));
    texture1_bytes = W_LumpLength(texture1_lump);

    if (texture1_bytes <= 0 || texture1_bytes > H3DIV_MAX_TEXTURE_BYTES)
    {
        I_Error("H3DIV FAIL stage=texture1-size bytes=%i max=%i",
                texture1_bytes, H3DIV_MAX_TEXTURE_BYTES);
    }

    maptex = maptex1 = W_CacheLumpNum(texture1_lump, PU_STATIC);
    W_ReadLump((unsigned int)texture1_lump, h3div_texture_shadow);

    if (memcmp(maptex1, h3div_texture_shadow,
               (size_t)texture1_bytes) != 0)
    {
        unsigned int initial_hash =
            H3DIV_Fnv1a(maptex1, (unsigned int)texture1_bytes);
        unsigned int reference_hash =
            H3DIV_Fnv1a(h3div_texture_shadow,
                        (unsigned int)texture1_bytes);
        unsigned int first = H3DIV_FirstMismatch(
            (const byte *)maptex1, h3div_texture_shadow,
            (unsigned int)texture1_bytes);
        byte initial_actual = ((const byte *)maptex1)[first];
        byte initial_expected = h3div_texture_shadow[first];

        printf("H3DIV isolate TEXTURE1: bytes=%i cache=%p shadow=%p "
               "initial=%08x reference=%08x first=%u actual=%02x expected_byte=%02x\n",
               texture1_bytes, (void *)maptex1,
               (void *)h3div_texture_shadow, initial_hash, reference_hash,
               first, initial_actual, initial_expected);

        /*
         * Re-read through the exact WAD path into the same Zone destination.
         * If this passes, the destination itself is writable and the initial
         * cache fill was the bad operation.
         */
        W_ReadLump((unsigned int)texture1_lump, maptex1);
        H3DIV_PrintCopyResult("same-dest-W_ReadLump",
                              (const byte *)maptex1,
                              h3div_texture_shadow,
                              (unsigned int)texture1_bytes);

        /*
         * Copy the known-good BSS snapshot with libc memcpy. This separates
         * WAD/stdio positioning from the memcpy implementation and destination
         * alignment used by the Zone allocation.
         */
        memcpy(maptex1, h3div_texture_shadow, (size_t)texture1_bytes);
        H3DIV_PrintCopyResult("BSS-to-zone-memcpy",
                              (const byte *)maptex1,
                              h3div_texture_shadow,
                              (unsigned int)texture1_bytes);

        /*
         * Finish with a deliberately simple byte-store loop. If this is the
         * only operation that produces a correct destination, the optimized
         * copy/read path is implicated rather than the Zone destination.
         */
        H3DIV_ByteCopy((byte *)maptex1, h3div_texture_shadow,
                       (unsigned int)texture1_bytes);
        H3DIV_PrintCopyResult("BSS-to-zone-bytecopy",
                              (const byte *)maptex1,
                              h3div_texture_shadow,
                              (unsigned int)texture1_bytes);

        if (memcmp(maptex1, h3div_texture_shadow,
                   (size_t)texture1_bytes) != 0)
        {
            I_Error("H3DIV FAIL stage=texture1-destination-unrecoverable "
                    "initial=%08x reference=%08x",
                    initial_hash, reference_hash);
        }

        printf("H3DIV TEXTURE1 repaired by diagnostic bytecopy; "
               "continuing initialization\n");
    }

    H3DIV_VerifyDoom1Reference("TEXTURE1", maptex1,
                              (unsigned int)texture1_bytes);

    numtextures1 = LONG(*maptex1);
    maxoff = texture1_bytes;
    directory = maptex1 + 1;

    if (numtextures1 <= 0 || numtextures1 > H3DIV_MAX_TEXTURES)
    {
        I_Error("H3DIV FAIL stage=texture-count count=%i max=%i",
                numtextures1, H3DIV_MAX_TEXTURES);
    }

    if (numtextures1 != LONG(*((int *)h3div_texture_shadow)))
    {
        I_Error("H3DIV FAIL stage=texture-count-copy cached=%i reread=%i",
                numtextures1,
                LONG(*((int *)h3div_texture_shadow)));
    }

    /*
     * Pre-scan the independent TEXTURE1 copy before any texture-object Zone
     * allocations occur. These offsets/hashes are our immutable reference.
     */
    for (i = 0; i < numtextures1; ++i)
    {
        int shadow_offset =
            LONG(((int *)h3div_texture_shadow)[1 + i]);
        maptexture_t *shadow_texture;
        unsigned int shadow_bytes;

        if (shadow_offset < (int)(sizeof(int) +
            (unsigned int)numtextures1 * sizeof(int)) ||
            shadow_offset >= texture1_bytes)
        {
            I_Error("H3DIV FAIL stage=shadow-directory tex=%i offset=%08x bytes=%i",
                    i, (unsigned int)shadow_offset, texture1_bytes);
        }

        shadow_texture =
            (maptexture_t *)(h3div_texture_shadow + shadow_offset);
        shadow_bytes = H3DIV_MapTextureBytes(shadow_texture);

        if ((unsigned int)shadow_offset + shadow_bytes >
            (unsigned int)texture1_bytes)
        {
            I_Error("H3DIV FAIL stage=shadow-texture-bounds tex=%i name=%.8s offset=%08x size=%u lump=%i",
                    i, shadow_texture->name,
                    (unsigned int)shadow_offset, shadow_bytes,
                    texture1_bytes);
        }

        h3div_raw_offset[i] = (unsigned int)shadow_offset;
        h3div_raw_hash[i] =
            H3DIV_Fnv1a(shadow_texture, shadow_bytes);
    }

    if (W_CheckNumForName(DEH_String("TEXTURE2")) != -1)
    {
        /*
         * The current ULX3S-12F reproducer uses DOOM1.WAD/shareware, which
         * has no TEXTURE2. Refuse a different IWAD instead of silently
         * weakening this diagnostic.
         */
        I_Error("H3DIV FAIL stage=unsupported-iwad reason=TEXTURE2-present");
    }
    else
    {
        maptex2 = NULL;
        numtextures2 = 0;
        maxoff2 = 0;
    }

    numtextures = numtextures1 + numtextures2;

    textures = Z_Malloc (numtextures * sizeof(*textures), PU_STATIC, 0);
    texturecolumnlump = Z_Malloc (numtextures * sizeof(*texturecolumnlump),
                                  PU_STATIC, 0);
    texturecolumnofs = Z_Malloc (numtextures * sizeof(*texturecolumnofs),
                                 PU_STATIC, 0);
    texturecomposite = Z_Malloc (numtextures * sizeof(*texturecomposite),
                                 PU_STATIC, 0);
    texturecompositesize = Z_Malloc (
        numtextures * sizeof(*texturecompositesize), PU_STATIC, 0);
    texturewidthmask = Z_Malloc (
        numtextures * sizeof(*texturewidthmask), PU_STATIC, 0);
    textureheight = Z_Malloc (
        numtextures * sizeof(*textureheight), PU_STATIC, 0);

    totalwidth = 0;

    temp1 = W_GetNumForName (DEH_String("S_START"));
    temp2 = W_GetNumForName (DEH_String("S_END")) - 1;
    temp3 = ((temp2-temp1+63)/64) + ((numtextures+63)/64);

    if (I_ConsoleStdout())
    {
        printf("[");
        for (i = 0; i < temp3 + 9; i++)
            printf(" ");
        printf("]");
        for (i = 0; i < temp3 + 10; i++)
            printf("\b");
    }

    h3div_recorded_textures = 0;

    for (i=0 ; i<numtextures ; i++, directory++)
    {
        int *expected_directory;
        int shadow_offset;
        maptexture_t *shadow_texture;
        unsigned int raw_bytes;
        unsigned int cached_raw_hash;

        if (!(i&63))
            printf (".");

        if (i == numtextures1)
        {
            maptex = maptex2;
            maxoff = maxoff2;
            directory = maptex+1;
        }

        expected_directory = maptex1 + 1 + i;

        if (directory != expected_directory)
        {
            I_Error("H3DIV FAIL stage=directory-pointer tex=%i expected=%p actual=%p",
                    i, expected_directory, directory);
        }

        shadow_offset = (int)h3div_raw_offset[i];
        offset = LONG(*directory);

        if (offset != shadow_offset)
        {
            I_Error("H3DIV FAIL stage=directory-word tex=%i expected=%08x actual=%08x dir=%p",
                    i, (unsigned int)shadow_offset,
                    (unsigned int)offset, directory);
        }

        if (offset > maxoff)
        {
            I_Error("H3DIV FAIL stage=directory-range tex=%i offset=%08x max=%08x",
                    i, (unsigned int)offset, (unsigned int)maxoff);
        }

        mtexture = (maptexture_t *)((byte *)maptex + offset);
        shadow_texture =
            (maptexture_t *)(h3div_texture_shadow + shadow_offset);
        raw_bytes = H3DIV_MapTextureBytes(shadow_texture);

        if (memcmp(mtexture, shadow_texture, raw_bytes) != 0)
        {
            I_Error("H3DIV FAIL stage=raw-texture-copy tex=%i expected=%.8s cached=%.8s bytes=%u expected_hash=%08x actual_hash=%08x",
                    i, shadow_texture->name, mtexture->name, raw_bytes,
                    h3div_raw_hash[i],
                    H3DIV_Fnv1a(mtexture, raw_bytes));
        }

        cached_raw_hash = H3DIV_Fnv1a(mtexture, raw_bytes);

        if (cached_raw_hash != h3div_raw_hash[i])
        {
            I_Error("H3DIV FAIL stage=raw-texture-hash tex=%i name=%.8s expected=%08x actual=%08x",
                    i, shadow_texture->name, h3div_raw_hash[i],
                    cached_raw_hash);
        }

        texture = textures[i] =
            Z_Malloc (sizeof(texture_t)
                      + sizeof(texpatch_t)*(SHORT(mtexture->patchcount)-1),
                      PU_STATIC, 0);

        texture->width = SHORT(mtexture->width);
        texture->height = SHORT(mtexture->height);
        texture->patchcount = SHORT(mtexture->patchcount);

        memcpy (texture->name, mtexture->name, sizeof(texture->name));
        mpatch = &mtexture->patches[0];
        patch = &texture->patches[0];

        for (j=0 ; j<texture->patchcount ; j++, mpatch++, patch++)
        {
            int pnames_index = SHORT(mpatch->patch);

            if (pnames_index < 0 || pnames_index >= nummappatches)
            {
                I_Error("H3DIV FAIL stage=patch-index tex=%i name=%.8s patch=%i pnames_index=%i count=%i",
                        i, texture->name, j, pnames_index,
                        nummappatches);
            }

            patch->originx = SHORT(mpatch->originx);
            patch->originy = SHORT(mpatch->originy);
            patch->patch = patchlookup[pnames_index];

            if (patch->patch == -1)
            {
                I_Error ("R_InitTextures: Missing patch in texture %s",
                         texture->name);
            }
        }

        h3div_texture_ptr[i] = texture;
        h3div_texture_width[i] = texture->width;
        h3div_texture_height[i] = texture->height;
        h3div_texture_patchcount[i] = texture->patchcount;
        memcpy(h3div_texture_name[i], texture->name, 8);
        h3div_texture_name[i][8] = '\0';
        h3div_texture_hash[i] = H3DIV_TextureHash(texture);
        h3div_recorded_textures = i + 1;

        H3DIV_VerifyTextureObject(i, "constructed");

        texturecolumnlump[i] = Z_Malloc (
            texture->width*sizeof(**texturecolumnlump), PU_STATIC,0);
        H3DIV_VerifyTextureObject(i, "after-columnlump-alloc");

        texturecolumnofs[i] = Z_Malloc (
            texture->width*sizeof(**texturecolumnofs), PU_STATIC,0);
        H3DIV_VerifyTextureObject(i, "after-columnofs-alloc");

        /*
         * Recheck the raw directory entry after the allocations. If Zone
         * activity or another write mutated the cached TEXTURE1 bytes, report
         * it at the texture where the first difference becomes visible.
         */
        if (LONG(*directory) != shadow_offset ||
            memcmp(mtexture, shadow_texture, raw_bytes) != 0)
        {
            I_Error("H3DIV FAIL stage=raw-mutated-after-alloc tex=%i expected=%.8s",
                    i, shadow_texture->name);
        }

        j = 1;
        while (j*2 <= texture->width)
            j<<=1;

        texturewidthmask[i] = j-1;
        textureheight[i] = texture->height<<FRACBITS;

        totalwidth += texture->width;
    }

    /*
     * Validate the complete pointer/object table before releasing TEXTURE1.
     */
    for (i = 0; i < numtextures; ++i)
    {
        H3DIV_VerifyTextureObject(i, "table-complete");
    }

    printf("H3DIV texture construction: PASS textures=%i\n", numtextures);

    Z_Free(patchlookup);

    W_ReleaseLumpName(DEH_String("TEXTURE1"));

    for (i = 0; i < numtextures; ++i)
    {
        H3DIV_VerifyTextureObject(i, "pre-lookup");
        R_GenerateLookup(i);
        H3DIV_VerifyTextureObject(i, "post-lookup");
    }

    printf("H3DIV texture lookup: PASS textures=%i\n", numtextures);

    texturetranslation = Z_Malloc (
        (numtextures+1)*sizeof(*texturetranslation), PU_STATIC, 0);

    for (i=0 ; i<numtextures ; i++)
        texturetranslation[i] = i;

    GenerateTextureHashTable();
}



//
// R_InitFlats
//
void R_InitFlats (void)
{
    int		i;
	
    firstflat = W_GetNumForName (DEH_String("F_START")) + 1;
    lastflat = W_GetNumForName (DEH_String("F_END")) - 1;
    numflats = lastflat - firstflat + 1;
	
    // Create translation table for global animation.
    flattranslation = Z_Malloc ((numflats+1)*sizeof(*flattranslation), PU_STATIC, 0);
    
    for (i=0 ; i<numflats ; i++)
	flattranslation[i] = i;
}


//
// R_InitSpriteLumps
// Finds the width and hoffset of all sprites in the wad,
//  so the sprite does not need to be cached completely
//  just for having the header info ready during rendering.
//
void R_InitSpriteLumps (void)
{
    int		i;
    patch_t	*patch;
	
    firstspritelump = W_GetNumForName (DEH_String("S_START")) + 1;
    lastspritelump = W_GetNumForName (DEH_String("S_END")) - 1;
    
    numspritelumps = lastspritelump - firstspritelump + 1;
    spritewidth = Z_Malloc (numspritelumps*sizeof(*spritewidth), PU_STATIC, 0);
    spriteoffset = Z_Malloc (numspritelumps*sizeof(*spriteoffset), PU_STATIC, 0);
    spritetopoffset = Z_Malloc (numspritelumps*sizeof(*spritetopoffset), PU_STATIC, 0);
	
    for (i=0 ; i< numspritelumps ; i++)
    {
	if (!(i&63))
	    printf (".");

	patch = W_CacheLumpNum (firstspritelump+i, PU_CACHE);
	spritewidth[i] = SHORT(patch->width)<<FRACBITS;
	spriteoffset[i] = SHORT(patch->leftoffset)<<FRACBITS;
	spritetopoffset[i] = SHORT(patch->topoffset)<<FRACBITS;
    }
}



//
// R_InitColormaps
//
void R_InitColormaps (void)
{
    int	lump;

    // Load in the light tables, 
    //  256 byte align tables.
    lump = W_GetNumForName(DEH_String("COLORMAP"));
    colormaps = W_CacheLumpNum(lump, PU_STATIC);
}



//
// R_InitData
// Locates all the lumps
//  that will be used by all views
// Must be called after W_Init.
//
void R_InitData (void)
{
    R_InitTextures ();
    printf (".");
    R_InitFlats ();
    printf (".");
    R_InitSpriteLumps ();
    printf (".");
    R_InitColormaps ();
}



//
// R_FlatNumForName
// Retrieval, get a flat number for a flat name.
//
int R_FlatNumForName (char* name)
{
    int		i;
    char	namet[9];

    i = W_CheckNumForName (name);

    if (i == -1)
    {
	namet[8] = 0;
	memcpy (namet, name,8);
	I_Error ("R_FlatNumForName: %s not found",namet);
    }
    return i - firstflat;
}




//
// R_CheckTextureNumForName
// Check whether texture is available.
// Filter out NoTexture indicator.
//
int	R_CheckTextureNumForName (char *name)
{
    texture_t *texture;
    int key;

    // "NoTexture" marker.
    if (name[0] == '-')		
	return 0;
		
    key = W_LumpNameHash(name) % numtextures;

    texture=textures_hashtable[key]; 
    
    while (texture != NULL)
    {
	if (!strncasecmp (texture->name, name, 8) )
	    return texture->index;

        texture = texture->next;
    }
    
    return -1;
}



//
// R_TextureNumForName
// Calls R_CheckTextureNumForName,
//  aborts with error message.
//
int	R_TextureNumForName (char* name)
{
    int		i;
	
    i = R_CheckTextureNumForName (name);

    if (i==-1)
    {
	I_Error ("R_TextureNumForName: %s not found",
		 name);
    }
    return i;
}




//
// R_PrecacheLevel
// Preloads all relevant graphics for the level.
//
int		flatmemory;
int		texturememory;
int		spritememory;

void R_PrecacheLevel (void)
{
    char*		flatpresent;
    char*		texturepresent;
    char*		spritepresent;

    int			i;
    int			j;
    int			k;
    int			lump;
    
    texture_t*		texture;
    thinker_t*		th;
    spriteframe_t*	sf;

    if (demoplayback)
	return;
    
    // Precache flats.
    flatpresent = Z_Malloc(numflats, PU_STATIC, NULL);
    memset (flatpresent,0,numflats);	

    for (i=0 ; i<numsectors ; i++)
    {
	flatpresent[sectors[i].floorpic] = 1;
	flatpresent[sectors[i].ceilingpic] = 1;
    }
	
    flatmemory = 0;

    for (i=0 ; i<numflats ; i++)
    {
	if (flatpresent[i])
	{
	    lump = firstflat + i;
	    flatmemory += lumpinfo[lump].size;
	    W_CacheLumpNum(lump, PU_CACHE);
	}
    }

    Z_Free(flatpresent);
    
    // Precache textures.
    texturepresent = Z_Malloc(numtextures, PU_STATIC, NULL);
    memset (texturepresent,0, numtextures);
	
    for (i=0 ; i<numsides ; i++)
    {
	texturepresent[sides[i].toptexture] = 1;
	texturepresent[sides[i].midtexture] = 1;
	texturepresent[sides[i].bottomtexture] = 1;
    }

    // Sky texture is always present.
    // Note that F_SKY1 is the name used to
    //  indicate a sky floor/ceiling as a flat,
    //  while the sky texture is stored like
    //  a wall texture, with an episode dependend
    //  name.
    texturepresent[skytexture] = 1;
	
    texturememory = 0;
    for (i=0 ; i<numtextures ; i++)
    {
	if (!texturepresent[i])
	    continue;

	texture = textures[i];
	
	for (j=0 ; j<texture->patchcount ; j++)
	{
	    lump = texture->patches[j].patch;
	    texturememory += lumpinfo[lump].size;
	    W_CacheLumpNum(lump , PU_CACHE);
	}
    }

    Z_Free(texturepresent);
    
    // Precache sprites.
    spritepresent = Z_Malloc(numsprites, PU_STATIC, NULL);
    memset (spritepresent,0, numsprites);
	
    for (th = thinkercap.next ; th != &thinkercap ; th=th->next)
    {
	if (th->function.acp1 == (actionf_p1)P_MobjThinker)
	    spritepresent[((mobj_t *)th)->sprite] = 1;
    }
	
    spritememory = 0;
    for (i=0 ; i<numsprites ; i++)
    {
	if (!spritepresent[i])
	    continue;

	for (j=0 ; j<sprites[i].numframes ; j++)
	{
	    sf = &sprites[i].spriteframes[j];
	    for (k=0 ; k<8 ; k++)
	    {
		lump = firstspritelump + sf->lump[k];
		spritememory += lumpinfo[lump].size;
		W_CacheLumpNum(lump , PU_CACHE);
	    }
	}
    }

    Z_Free(spritepresent);
}




