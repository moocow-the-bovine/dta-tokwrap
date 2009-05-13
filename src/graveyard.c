//--------------------------------------------------------------
ByteOffset mark_discontinuous_segments(cxData *cxd, cxAuxRecord *cxaux)
{
  ByteOffset   cxi;
  cxRecord    *cx,  *cx_prev=NULL;
  cxAuxRecord *cxa, *cxa_prev=NULL;
  txmlToken    *w,  *w_prev=NULL;
  txmlSentence *s,  *s_prev=NULL;
  ByteOffset ndiscont=0;

  //-- scan for first claimed character
  for (cxi=0; cxi < cxd->len && !(cxaux[cxi].flags&cxafWAny); cxi++) ;
  cx_prev  = &cxd->data[cxi];
  cxa_prev = &cxaux[cxi];
  w_prev   = ((cxa_prev->flags&cxafWAny)           ? &txmld->wdata[cxa_prev->w_i] : NULL);
  s_prev   = ((cxa_prev->flags&cxafSAny) && w_prev ? &txmld->sdata[w_prev->s_i] : NULL);

  for (cxi++; cxi < cxd->len; cxi++) {
    cx  = &cxd->data[cxi];
    cxa = &cxaux[cxi];
    w   = ((cxa->flags&cxafWAny)      ? &txmld->wdata[cxa->w_i] : NULL);
    s   = ((cxa->flags&cxafSAny) && w ? &txmld->sdata[w->s_i] : NULL);

    //-- ignore unclaimed characters
    if ( !(cxa->flags&cxafWAny) ) continue;

    //-- check for token discontinuity
    if ( w_prev && w != w_prev && !(cxa->flags&cxafWBegin) ) {
      cxa_prev->flags |= cxafWxEnd;
      cxa->flags      |= cxafWxBegin;
      ++ndiscont;
#if 1
      fprintf(stderr, "w discontinuity[%s/%s]: c=%s | c=%s \n",
	      (w_prev ? w_prev->w_id : "(null)"),
	      (w      ? w->w_id      : "(null)"),
	      cx_prev->id, cx->id);
#endif
    }

    //-- check for sentence discontinuity
    if ( s_prev && s != s_prev && !(cxa->flags&cxafSBegin) ) {
      cxa_prev->flags |= cxafSxEnd;
      cxa->flags      |= cxafSxBegin;
      ++ndiscont;
#if 1
     fprintf(stderr, "s discontinuity[%s/%s]~(%s/%s): c=%s | c=%s \n",
	      (s_prev ? s_prev->s_id : "(null)"), (s ? s->s_id : "(null)"),
	      (w_prev ? w_prev->w_id : "(null)"), (w ? w->w_id : "(null)"),
	      cx_prev->id, cx->id);
#endif
      }

    //-- update
    cx_prev = cx;
    cxa_prev = cxa;
    w_prev = w;
    s_prev = s;
  }

  return ndiscont;
}

//--------------------------------------------------------------
ByteOffset mark_discontinuous_segments(cxData *cxd, cxAuxRecord *cxaux)
{
  ByteOffset cxi;
  cxRecord *cx, *cx_prev=NULL, *cx_end=cxd->data+cxd->len;
  cxAuxRecord *cxa, *cxa_prev=NULL;
  txmlToken *w, *w_prev=NULL;
  ByteOffset ndiscont = 0;

  for (cx=cxd->data,cxa=cxaux; cx < cx_end; cx++, cxa++) {
    if (cx==NULL || cxa==NULL) continue;
    w = &txmldata.wdata[cxa->w_i];

    if ( cxa_prev && !(cxa->flags&cxafWBegin) && cxa->w_i != cxa_prev->w_i) {
      //-- token or token-segment boundary
      cxa_prev->flags |= cxafWxEnd;
      cxa->flags      |= cxafWxBegin;
      ++ndiscont;
#if 1
      fprintf(stderr, "w discontinuity[%s/%s]: c=%s/w~%lu | c=%s/w~%lu \n",
	      (w_prev ? w_prev->w_id : "(null)"),
	      (w ? w->w_id : "(null)"),
	      cx_prev->id, cxa_prev->w_i,
	      cx->id,  cxa->w_i);
#endif
    }
    if ( w && w_prev && !(cxa->flags&cxafSBegin) && w->s_i != w_prev->s_i) {
      //-- sentence or sentence-segment boundary
      cxa_prev->flags |= cxafSxEnd;
      cxa->flags      |= cxafSxBegin;
      ++ndiscont;
#if 1
      fprintf(stderr, "s discontinuity[%s~%lu/%s~%lu]: c=%s/w~%lu | c=%s/w~%lu \n",
	      (w_prev ? w_prev->w_id : "(null)"), (w_prev ? w_prev->s_i : -1),
	      (w ? w->w_id : "(null)"), (w ? w->s_i : -1),
	      cx_prev->id, cxa_prev->w_i,
	      cx->id,  cxa->w_i);
#endif
    }

    //-- update
    cx_prev = cx;
    cxa_prev = cxa;
    if (w) w_prev = w;
  }
  return ndiscont;
}


//--------------------------------------------------------------
// loadTxtFile(f)
//  + allocates & populates txdata from FILE *f
//  + requires loaded cxdata
static void loadTxFile(FILE *f)
{
  cxRecord *cx_final;
  size_t     nread;
  assert(cxdata != NULL /* require loaded cx data */);
  assert(ncxdata > 0    /* require non-empty cx index */);

  cx_final = &cxdata[ncxdata-1];
  ntxdata = cx_final->toff + cx_final->tlen;

  txdata = (char*)malloc(ntxdata);
  assert(txdata != NULL /* malloc failed */);

  nread = fread(txdata, 1, (size_t)ntxdata, f);
  assert(nread==ntxdata /* load tx data failed */);
}
