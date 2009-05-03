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
