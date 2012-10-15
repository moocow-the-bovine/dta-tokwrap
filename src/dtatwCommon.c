#include "dtatwCommon.h"
#include <sys/stat.h>

/*======================================================================
 * Globals
 */
char *prog = "dtatwCommon"; //-- used for error reporting
char *CX_NIL_ELT = "-";
char *CX_FORMULA_TEXT  = " FORMULA ";
//char *xmlid_name = "xml:id";
char *xmlid_name = "id";

//-- foward decl (lives in string.h)
extern char *basename(const char *path);

/*======================================================================
 * Utils: basename
 */
char *file_basename(char *dst, const char *src, const char *suff, int srclen, int dstlen)
{
  const char *b = basename(src);
  int blen = strlen(b);
  int suflen = suff ? strlen(suff) : 0;
  if (suff && blen >= suflen && strcmp(suff,b+blen-suflen)==0) { blen -= suflen; }

  //-- maybe allocate dst
  if (dst==NULL) {
    if (dstlen <= 0) dstlen  = blen+1;
    else             dstlen += blen+1;
    dst = (char*)malloc(dstlen);
    assert(dst != NULL /* malloc error */);
  }

  //-- copy
  assert(dstlen > blen /* buffer overflow */);
  memcpy(dst, b, blen);
  dst[blen] = '\0';

  return dst;
}

/*======================================================================
 * Utils: slurp
 */

//--------------------------------------------------------------
off_t file_size(FILE *f)
{
  struct stat st;
  if (fstat(fileno(f), &st) != 0) {
    fprintf(stderr, "file_size(): ERROR: %s\n", strerror(errno));
    exit(255);
  }
  return st.st_size;
}

//--------------------------------------------------------------
size_t file_slurp(FILE *f, char **bufp, size_t buflen)
{
  size_t nread=0;
  if (buflen==0) {
    size_t nwanted = file_size(f) - ftello(f);
    *bufp = (char*)malloc(nwanted);
    assert2(*bufp != NULL, "malloc failed");
    buflen = nwanted;
  }
  assert2(bufp != NULL && *bufp != NULL, "bad buffer for file_slurp()");
  nread = fread(*bufp, sizeof(char), buflen, f);
  return nread;
}

/*======================================================================
 * Utils: cx: packed
 */


//-- cx: packed: flags
const uchar cxfTypeMask = 0x7;
const uchar cxfHasXmlOffset = 0x8;
const uchar cxfHasTxtLength = 0x10;
const uchar cxfHasAttrs = 0x20;
const uchar cxfUnused1 = 0x40;
const uchar cxfUnused2 = 0x80;

//-- cx: packed: header
const uchar    *cxMagic      = "dtatw binary cx";
const uint32_t cxhVersion    = 0;
const uint32_t cxhVersionMin = 0;

//--------------------------------------------------------------
void cx_put_header(FILE *f)
{
  //-- header: magic
  uchar magic[32];
  memset(magic,0,32);
  strcpy(magic,cxMagic);
  fwrite(magic,32,1,f);

  //-- header: version stuff
  fwrite(&cxhVersion,    4, 1, f);
  fwrite(&cxhVersionMin, 4, 1, f);
}

//--------------------------------------------------------------
void cx_get_header(FILE *f, const char *filename)
{
  int rc = 1;
  uchar magic[32];
  uint32_t vinfo[2];
  if (fread(magic,32,1,f) != 32) {
    fprintf(stderr, "%s: failed to read magic from cx file %s\n", (filename ? filename : "NULL"));
    exit(1);
  }
  if (strcmp(magic,cxMagic) != 0) {
    fprintf(stderr, "%s: bad magic from cx file %s\n", (filename ? filename : "NULL"));
    exit(1);
  }

  if (fread(vinfo,4,2,f) != 8) {
    fprintf(stderr, "%s: failed to read version info from cx file %s\n", (filename ? filename : "NULL"));
    exit(1);
  }
  if (vinfo[1] > cxhVersion) {
    fprintf(stderr, "%s: cx file %s requires cx-version %u, but we have only %u\n", (filename ? filename : "NULL"), vinfo[1], cxhVersion);
    exit(1);
  }
  if (cxhVersionMin > vinfo[0]) {
    fprintf(stderr, "%s: we require cx-version %u, but cx file %s is only %u\n", (filename ? filename : "NULL"), cxhVersionMin, vinfo[0]);
    exit(1);
  }
}

//--------------------------------------------------------------
void cx_put_record(FILE *f, const cxStoredRecord *cxr)
{
  fputc(cxr->flags,f);
  if (cxr->flags & cxfHasXmlOffset)
    fwrite(&cxr->xoff,4,1,f);
  fputc(cxr->xlen,f);
  if (cxr->flags & cxfHasTxtLength)
    fputc(cxr->tlen,f);
  if (cxr->flags & cxfHasAttrs)
    fwrite(cxr->attrs,4,4,f);
}

//--------------------------------------------------------------
void cx_get_record(FILE *f, cxStoredRecord *cxr, uint32_t *xmlOffset)
{
  assert(!feof(f));
  cxr->flags = fgetc(f);

  if (cxr->flags & cxfHasXmlOffset)
    fread(&cxr->xoff,4,1,f);
  else
    cxr->xoff = (xmlOffset ? *xmlOffset : 0);

  cxr->xlen = fgetc(f);

  if (cxr->flags & cxfHasTxtLength)
    cxr->tlen = fgetc(f);
  else
    cxr->tlen = cxr->xlen;

  if (cxr->flags & cxfHasAttrs)
    fread(cxr->attrs,4,4,f);
}

//--------------------------------------------------------------
void put_paced_w(FILE *f, ByteOffset i)
{
  for (; i >= 0x80; i >>= 7) {
    fputc( (0x80 | (i&0x7f)), f );
  }
  fputc( (i&0x7f), f );
}

//--------------------------------------------------------------
ByteOffset get_packed_w(FILE *f)
{
  int c;
  ByteOffset i;
  for (i=0, c=fgetc(f); (c&0x80); c=fgetc(f)) {
    i = (i<<7) | (c & 0x7f);
  }
  return (i<<7) | (c & 0x7f);
}


/*======================================================================
 * Utils: .cx file(s)
 */

//--------------------------------------------------------------
cxData *cxDataInit(cxData *cxd, size_t size)
{
  if (size==0) {
    size = CXDATA_DEFAULT_ALLOC;
  }
  if (!cxd) {
    cxd = (cxData*)malloc(sizeof(cxData));
    assert(cxd != NULL /* malloc failed */);
  }
  cxd->data = (cxRecord*)malloc(size*sizeof(cxRecord));
  assert(cxd->data != NULL /* malloc failed */);
  cxd->len   = 0;
  cxd->alloc = size;
  return cxd;
}

//--------------------------------------------------------------
cxRecord *cxDataPush(cxData *cxd, cxRecord *cx)
{
  if (cxd->len+1 >= cxd->alloc) {
    //-- whoops: must reallocate
    cxd->data = (cxRecord*)realloc(cxd->data, cxd->alloc*2*sizeof(cxRecord));
    assert(cxd->data != NULL /* realloc failed */);
    cxd->alloc *= 2;
  }
  //-- just push copy raw data, pointers & all
  memcpy(&cxd->data[cxd->len], cx, sizeof(cxRecord));
  return &cxd->data[cxd->len++];
}

//--------------------------------------------------------------
#define INITIAL_CX_LINEBUF_SIZE 1024
cxData *cxDataLoad(cxData *cxd, FILE *f)
{
  cxRecord cx;
  char *linebuf=NULL;
  size_t linebuf_alloc=0;
  ssize_t linelen;
  char *s0, *s1;

  if (cxd==NULL || cxd->data==NULL) cxd=cxDataInit(cxd,0);
  assert(f!=NULL /* require .cx file */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_CX_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_CX_LINEBUF_SIZE;

  while ( (linelen=getline(&linebuf,&linebuf_alloc,f)) >= 0 ) {
    char *tail;
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    //-- elt
    s0  = linebuf;
    s1  = next_tab_z(s0);
    cx.elt = strdup(s0);

    //-- xoff
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.xoff = strtoul(s0,&tail,0);

    //-- xlen
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.xlen = strtol(s0,&tail,0);

    //-- toff
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.toff = strtoul(s0,&tail,0);

    //-- tlen
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.tlen = strtol(s0,&tail,0);

    //-- bxp
    cx.bxp = NULL;
    cx.claimed = 0;

    cxDataPush(cxd, &cx);
  }

  //-- cleanup & return
  if (linebuf) free(linebuf);
  return cxd;
}


//--------------------------------------------------------------
// un-escapes cx file text string to a new string; returns newly allocated string
char *cx_text_string(char *src, int src_len)
{
  int i,j;
  char *dst = (char*)malloc(src_len);
  for (i=0,j=0; src[i] && i < src_len; i++,j++) {
    switch (src[i]) {
    case '\\': {
      i++;
      switch (src[i]) {
      case '0': dst[j] = '\0'; break;
      case 'n': dst[j] = '\n'; break;
      case 't': dst[j] = '\t'; break;
      case '\\': dst[j] = '\\'; break;
      default: dst[j] = src[i]; break;
      }
    }
    default:
      dst[j] = src[i];
      break;
    }
  }
  dst[j] = '\0';
  return dst;
}



/*======================================================================
 * Utils: .bx file(s)
 */

//--------------------------------------------------------------
bxData *bxDataInit(bxData *bxd, size_t size)
{
  if (size==0) size = BXDATA_DEFAULT_ALLOC;
  if (!bxd) {
    bxd = (bxData*)malloc(sizeof(bxData));
    assert(bxd != NULL /* malloc failed */);
  }
  bxd->data = (bxRecord*)malloc(size*sizeof(bxRecord));
  assert(bxd->data != NULL /* malloc failed */);
  bxd->len   = 0;
  bxd->alloc = size;
  return bxd;
}

//--------------------------------------------------------------
bxRecord *bxDataPush(bxData *bxd, bxRecord *bx)
{
  if (bxd->len+1 >= bxd->alloc) {
    //-- whoops: must reallocate
    bxd->data = (bxRecord*)realloc(bxd->data, bxd->alloc*2*sizeof(bxRecord));
    assert(bxd->data != NULL /* realloc failed */);
    bxd->alloc *= 2;
  }
  //-- just push copy raw data, pointers & all
  memcpy(&bxd->data[bxd->len], bx, sizeof(bxRecord));
  return &bxd->data[bxd->len++];
}

//--------------------------------------------------------------
#define INITIAL_BX_LINEBUF_SIZE 1024
bxData *bxDataLoad(bxData *bxd, FILE *f)
{
  bxRecord bx;
  char *linebuf=NULL, *s0, *s1;
  size_t linebuf_alloc=0;
  ssize_t linelen;

  if (bxd==NULL || bxd->data==NULL) bxd=bxDataInit(bxd,0);
  assert(f!=NULL /* require .bx file */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_BX_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_BX_LINEBUF_SIZE;

  while ( (linelen=getline(&linebuf,&linebuf_alloc,f)) >= 0 ) {
    char *tail;
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    //-- key
    s0  = linebuf;
    s1  = next_tab_z(s0);
    bx.key = strdup(s0);

    //-- elt
    s0 = s1+1;
    s1 = next_tab_z(s0);
    bx.elt = strdup(s0);

    //-- xoff
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.xoff = strtoul(s0,&tail,0);

    //-- xlen
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.xlen = strtoul(s0,&tail,0);

    //-- toff
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.toff = strtoul(s0,&tail,0);

    //-- tlen
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.tlen = strtol(s0,&tail,0);

    //-- otoff
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.otoff = strtoul(s0,&tail,0);

    //-- otlen
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.otlen = strtol(s0,&tail,0);

    bxDataPush(bxd, &bx);
  }

  //-- cleanup & return
  if (linebuf) free(linebuf);
  return bxd;
}

/*======================================================================
 * Utils: indexing
 */

//--------------------------------------------------------------
/* tx2cxIndex()
 *  + allocates & populates tb2ci lookup vector: cxRecord *cx = tx2cx->data[tx_byte_index]
 *  + requires loaded, non-empty cxdata
 */
Offset2CxIndex  *tx2cxIndex(Offset2CxIndex *txo2cx, cxData *cxd)
{
  cxRecord *cx;
  ByteOffset ntxb, cxi, txi, t_end;
  assert(cxd != NULL && cxd->data != NULL /* require loaded cx data */);
  assert(cxd->len > 0 /* require non-empty cx index */);

  //-- maybe allocate top-level index struct
  if (txo2cx==NULL) {
    txo2cx = (Offset2CxIndex*)malloc(sizeof(Offset2CxIndex));
    assert(txo2cx != NULL /* malloc failed */);
    txo2cx->data = NULL;
    txo2cx->len  = 0;
  }

  //-- get number of required records, maybe (re-)allocate index vector
  cx     = &cxd->data[cxd->len-1];
  ntxb   = cx->toff + cx->tlen;
  if (txo2cx->len < ntxb) {
    if (txo2cx->data) free(txo2cx->data);
    txo2cx->data = (cxRecord**)malloc(ntxb*sizeof(cxRecord*));
    assert(txo2cx->data != NULL /* malloc failed for tx-byte to cx-record lookup vector */);
    memset(txo2cx->data, 0, ntxb*sizeof(cxRecord*)); //-- zero the block
    txo2cx->len = ntxb;
  }

  //-- ye olde loope
  for (cxi=0; cxi < cxd->len; cxi++) {
    //-- map ALL tx-bytes generated by this 'c' to a pointer (may cause token overlap (which is handled later))
    cx = &cxd->data[cxi];
    t_end = cx->toff+cx->tlen;
    for (txi=cx->toff; txi < t_end; txi++) {
      txo2cx->data[txi] = cx;
    }
  }

  return txo2cx;
}

//--------------------------------------------------------------
/* txt2cxIndex()
 *  + allocates & populates txtb2cx lookup vector: cxRecord *cx = txtb2cx[txt_byte_index]
 *  + also sets cx->bxp to point to block from bxd
 *  + requires:
 *    - populated bxdata[] vector (see loadBxFile())
 *    - populated txb2ci[] vector (see init_txb2ci())
 */
Offset2CxIndex *txt2cxIndex(Offset2CxIndex *txto2cx, bxData *bxd, Offset2CxIndex *txb2cx)
{
  bxRecord *bx;
  ByteOffset ntxtb, bxi, txti, ot_end;
  assert(bxd != NULL && bxd->data != NULL /* require loaded bx data */);
  assert(bxd->len > 0    /* require non-empty bx index */);

  //-- maybe allocate top-level index struct
  if (txto2cx==NULL) {
    txto2cx = (Offset2CxIndex*)malloc(sizeof(Offset2CxIndex));
    assert(txto2cx != NULL /* malloc failed */);
    txto2cx->data = NULL;
    txto2cx->len  = 0;
  }

  //-- get number of required records, maybe (re-)allocate index vector
  bx      = &bxd->data[bxd->len-1];
  ntxtb   = bx->otoff + bx->otlen;
  if (txto2cx->len < ntxtb) {
    if (txto2cx->data) free(txto2cx->data);
    txto2cx->data = (cxRecord**)malloc(ntxtb*sizeof(cxRecord*));
    assert(txto2cx->data != NULL /* malloc failed for tx-byte to cx-record lookup vector */);
    memset(txto2cx->data, 0, ntxtb*sizeof(cxRecord*)); //-- zero the block
    txto2cx->len = ntxtb;
  }

  //-- ye olde loope
  for (bxi=0; bxi < bxd->len; bxi++) {
    bx = &bxd->data[bxi];
    if (bx->tlen > 0) {
      //-- "normal" text which SHOULD have corresponding cx records
      for (txti=0; txti < bx->otlen; txti++) {
	cxRecord *cx = txb2cx->data[bx->toff+txti];
	txto2cx->data[bx->otoff+txti] = cx;
	if (cx != NULL) cx->bxp = bx; //-- cache block pointer for cx
      }
    }
    //-- hints and other pseudo-text with NO cx records are mapped to NULL (via memset(), above)
  }

  return txto2cx;
}

//--------------------------------------------------------------
/* cx2bxIndex() :: UNUSED (?!)
 *  + allocates & populates cx2bx: bxRecord *bx = cx2bx[cx_index]
 *  + requires populated cxd, bxd
 */
bxRecord **cx2bxIndex(cxData *cxd, bxData *bxd, Offset2CxIndex *tx2cx)
{
  bxRecord **cx2bx;
  ByteOffset bxi, txi, cxi;

  //-- sanity checks
  assert(cxd != NULL);
  assert(bxd != NULL);
  assert(tx2cx != NULL);
  assert(cxd->data != NULL);
  assert(bxd->data != NULL);
  assert(tx2cx->data != NULL);

  //-- allocate index vector
  cx2bx = (bxRecord**)malloc(cxd->len*sizeof(bxRecord*));
  assert2(cx2bx != NULL, "malloc failed");

  //-- populate index vector
  for (bxi=0; bxi < bxd->len; bxi++) {
    bxRecord *bx = &bxd->data[bxi];
    for (txi=0; txi < bx->tlen; txi++) {
      cxRecord *cx = tx2cx->data[txi];
      if (cx==NULL) continue; //-- skip pseudo-records
      cxi = cx-&cxd->data[0];
      cx2bx[cxi] = bx;
    }
  }

  return cx2bx;
}

//--------------------------------------------------------------
int cx_is_adjacent(const cxRecord *cx1, const cxRecord *cx2) {
  if (!cx1 || !cx2) return 0;				//-- NULL records block adjacency
  if (cx1->xoff+cx1->xlen == cx2->xoff) return 1;	//-- immediate XML adjaceny at byte-level
  if (cx1->bxp==cx2->bxp && cx2==(cx1+1)) return 1;	//-- immediate adjacency in .cx-file within a single block from .bx-file
  return 0;
}

