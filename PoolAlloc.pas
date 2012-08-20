unit PoolAlloc;

interface

uses
  Windows, Sysutils;

const
  ALLOC_PAGE_SIZE     = 4096;
  MAX_ALLOC_FROM_POOL = (ALLOC_PAGE_SIZE - 1);
  DEFAULT_POOL_SIZE   = (16 * 1024);
  //MIN_POOL_SIZE       = (sizeof(ngx_pool_t) + 2 * sizeof(ngx_pool_large_t));


implementation

end.
