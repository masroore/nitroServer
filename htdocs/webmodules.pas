[!outputoff]
// 1.1
[!outputon]
[!if=(IsapiSource, "TRUE")]
library %s;

uses
  ActiveX,
  ComObj,
  WebBroker,
  ISAPIApp,
  ISAPIThreadPool;

{$R *.res}

exports
  GetExtensionVersion,
  HttpExtensionProc,
  TerminateExtension;

begin
  CoInitFlags := COINIT_MULTITHREADED;
  Application.Initialize;
  Application.Run;
end.
[!endif]
[!if=(WinCGISource, "TRUE")]
program %s;

{$APPTYPE %s}

uses
  WebBroker,
  CGIApp;

{$R *.res}

begin
  Application.Initialize;
  Application.Run;
end.
[!endif]
[!if=(CGISource, "TRUE")]
program %s;

{$APPTYPE %s}

uses
  WebBroker,
  CGIApp;

{$R *.res}

begin
  Application.Initialize;
  Application.Run;
end.
[!endif]
[!if=(WebModuleSource, "TRUE")]
unit %0:s;

interface

uses
  SysUtils, Classes, HTTPApp;

type
  T%1:s = class(T%2:s)
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  %1:s: T%1:s;

implementation

[!if=(Clx, "TRUE")]
{$R *.xfm}
[!else]
{$R *.dfm}
[!endif]

end.
[!endif]
[!if=(WinModuleIntf, "TRUE")]
//$$ -- WebModule Interface -- (stWebModuleIntf)
 // { Placeholder for C++}
[!endif]
[!if=(COMProjectSource, "TRUE")]
program %s;

{$APPTYPE %s}

uses
[!if=(Clx, "TRUE")]
  QForms,
[!else]
  Forms,
[!endif]
  SockApp;

{$R *.res}

begin
  Application.Initialize;
  Application.Run;
end.
[!endif]
[!if=(COMModuleSource, "TRUE")]
unit %0:s;

interface

uses
  SysUtils, Classes, HTTPApp;

type
  T%1:s = class(T%2:s)
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  %1:s: T%1:s;

implementation

uses WebReq;

[!if=(Clx, "TRUE")]
{$R *.xfm}
[!else]
{$R *.dfm}
[!endif]

initialization
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := T%1:s;

end.
[!endif]
[!if=(COMConsoleSource, "TRUE")]
unit %0:s;

interface

uses
[!if=(Clx, "TRUE")]
  SysUtils, Classes, QForms;
[!else]
  SysUtils, Classes, Forms;
[!endif]

type
  T%1:s = class(T%2:s)
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  %1:s: T%1:s;

implementation

uses SockApp;

[!if=(Clx, "TRUE")]
{$R *.xfm}
[!else]
{$R *.dfm}
[!endif]

initialization
  TWebAppSockObjectFactory.Create('%3:s')

end.
[!endif]
[!if=(COMConsoleIntf, "TRUE")]
 //$$ -- COMApp Form Interface -- (stCOMConsoleIntf)
 // {Placeholder for C++}
[!endif]
[!if=(Apache, "TRUE")]
library %s;

uses
  WebBroker,
  ApacheApp;

{$R *.res}

exports
  apache_module name '%0:s_module';

begin
  Application.Initialize;
  Application.Run;
end.
[!endif]
[!if=(ApacheTwo, "TRUE")]
library %s;

uses
  WebBroker,
  ApacheTwoApp;

{$R *.res}

exports
  apache_module name '%0:s_module';

begin
  Application.Initialize;
  Application.Run;
end.
[!endif]
[!if=(SOAPWebModuleSource, "TRUE")]
unit %0:s;

interface

uses
  SysUtils, Classes, HTTPApp;

type
  T%1:s = class(T%2:s)
    HTTPSoapDispatcher1: THTTPSoapDispatcher;
    HTTPSoapPascalInvoker1: THTTPSoapPascalInvoker;
    WSDLHTMLPublish1: TWSDLHTMLPublish;
    procedure %1:sDefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  %1:s: T%1:s;

implementation

[!if=(Clx, "TRUE")]
{$R *.xfm}
[!else]
{$R *.dfm}
[!endif]

procedure T%1:s.%1:sDefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  WSDLHTMLPublish1.ServiceInfo(Sender, Request, Response, Handled);
end;

end.
[!endif]
[!if=(SOAPWebModuleIntf, "TRUE")]
 //$$ -- SOAP Web Module Interface -- (stSOAPWebModuleIntf)
 // {Placeholder for C++}
[!endif]
[!if=(SOAPCOMModuleSource, "TRUE")]
unit %0:s;

interface

uses
  SysUtils, Classes, HTTPApp;

type
  T%1:s = class(T%2:s)
    HTTPSoapDispatcher1: THTTPSoapDispatcher;
    HTTPSoapPascalInvoker1: THTTPSoapPascalInvoker;
    WSDLHTMLPublish1: TWSDLHTMLPublish;
    procedure %1:sDefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  %1:s: T%1:s;

implementation

uses WebReq;

[!if=(Clx, "TRUE")]
{$R *.xfm}
[!else]
{$R *.dfm}
[!endif]

procedure T%1:s.%1:sDefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  WSDLHTMLPublish1.ServiceInfo(Sender, Request, Response, Handled);
end;

initialization
  WebRequestHandler.WebModuleClass := T%1:s;

end.
[!endif]
[!if=(SOAPCOMModuleIntf, "TRUE")]
 //$$ -- SOAP COMApp WebModule Interface -- (stSOAPCOMModuleIntf)
 // {Placeholder for C++}
[!endif]
[!if=(SOAPCOMConsoleSource, "TRUE")]
unit %0:s;

interface

uses
[!if=(Clx, "TRUE")]
  SysUtils, Classes, QForms;
[!else]
  SysUtils, Classes, Forms;
[!endif]

type
  T%1:s = class(T%2:s)
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  %1:s: T%1:s;

implementation

uses SockApp;

[!if=(Clx, "TRUE")]
{$R *.xfm}
[!else]
{$R *.dfm}
[!endif]

initialization
  TWebAppSockObjectFactory.Create('%3:s');

end.
[!endif]
[!if=(SOAPCOMConsoleIntf, "TRUE")]
 //$$ -- SOAP Form Interface -- (stSOAPCOMConsoleIntf)
 // {Placeholder for C++}
[!endif]
