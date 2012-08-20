[!outputoff]
[!if=(Filecomments, "True")]
* stWebModuleSource
* 0 - FModuleIdent
* 1 - FFormIdent
* 2 - FAncestorIdent
* 3 - Uses
* 4 - Factory
* 5 - Components
* 6 - HTML comment
[!endif]
[!outputon]
[!if=(WebModuleSource, "True")]
unit %0:s;

interface

uses
  SysUtils, Classes, HTTPApp, WebModu%3:s;

type
  T%1:s = class(T%2:s)%5:s
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  function %1:s: T%1:s;

implementation

[!if=(Clx, "TRUE")]
{$R *.xfm} %6:s
[!else]
{$R *.dfm} %6:s
[!endif]

uses WebReq, WebCntxt, WebFact, Variants;

function %1:s: T%1:s;
begin
  Result := T%1:s(WebContext.FindModuleClass(T%1:s));
end;

initialization
  if WebRequestHandler <> nil then
    WebRequestHandler.AddWebModuleFactory(%4:s);

end.
[!endif]
[!if=(WebModuleIntf, "True")]
* stWebModuleIntf
[!endif]
[!if=(WebAppPageModuleFactory, "True")]
[!outputoff]
* stWebAppPageModuleFactory
* 0 - Form
* 1 - CreateMode (ignored)
* 2 - CacheMode
* 3 - PageInfo
[!outputon]
TWebAppPageModuleFactory.Create(T%0:s, TWebPageInfo.Create(%3:s), %2:s)
[!endif]
[!if=(WebAppDataModuleFactory, "True")] 
[!outputoff]
* stWebAppDataModuleFactory
* 0 - Form
* 1 - CreateMode (ignored)
* 2 - CacheMode
[!outputon]
TWebAppDataModuleFactory.Create(T%0:s, %2:s)
[!endif]
[!if=(WebPageModuleFactory, "True")]
[!outputoff]
* stWebPageModuleFactory
* 0 - Form
* 1 - CreateMode
* 2 - CacheMode
* 3 - PageInfo
[!outputon]
TWebPageModuleFactory.Create(T%0:s, TWebPageInfo.Create(%3:s), %1:s, %2:s)
[!endif]
[!if=(WebDataModuleFactory, "True")]
[!outputoff]
* stWebDataModuleFactory
* 0 - Form
* 1 - CreateMode
* 2 - CacheMode
[!outputon]
TWebDataModuleFactory.Create(T%0:s, %1:s, %2:s)
[!endif]

