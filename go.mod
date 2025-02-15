module github.com/openziti/ziti

go 1.17

//replace github.com/openziti/foundation => ../foundation

//replace github.com/openziti/dilithium => ../dilithium

//replace github.com/openziti/fabric => ../fabric

//replace github.com/openziti/sdk-golang => ../sdk-golang

//replace github.com/openziti/edge => ../edge

//replace github.com/michaelquigley/pfxlog => ../pfxlog

//replace go.etcd.io/bbolt => github.com/openziti/bbolt v1.3.6-0.20210317142109-547da822475e

require (
	github.com/Jeffail/gabs v1.4.0
	github.com/MakeNowJust/heredoc v1.0.0
	github.com/MichaelMure/go-term-markdown v0.1.4
	github.com/alecthomas/chroma v0.9.2
	github.com/blang/semver v3.5.1+incompatible
	github.com/fatih/color v1.13.0
	github.com/fullsailor/pkcs7 v0.0.0-20190404230743-d7302db945fa
	github.com/go-acme/lego/v4 v4.2.0
	github.com/go-openapi/runtime v0.22.0
	github.com/go-openapi/strfmt v0.21.1
	github.com/golang/glog v0.0.0-20160126235308-23def4e6c14b
	github.com/golang/protobuf v1.5.2
	github.com/google/go-cmp v0.5.7
	github.com/influxdata/influxdb1-client v0.0.0-20191209144304-8bf82d3c094d
	github.com/keybase/go-ps v0.0.0-20190827175125-91aafc93ba19
	github.com/michaelquigley/pfxlog v0.6.3
	github.com/openziti/edge v0.21.79
	github.com/openziti/fabric v0.17.37
	github.com/openziti/foundation v0.17.1
	github.com/openziti/sdk-golang v0.16.2
	github.com/pborman/uuid v1.2.0
	github.com/pkg/errors v0.9.1
	github.com/rcrowley/go-metrics v0.0.0-20200313005456-10cdbea86bc0
	github.com/russross/blackfriday v1.5.2
	github.com/shirou/gopsutil v2.21.11+incompatible
	github.com/sirupsen/logrus v1.8.1
	github.com/spf13/cobra v1.3.0
	github.com/spf13/pflag v1.0.5
	github.com/spf13/viper v1.10.0
	github.com/stretchr/testify v1.7.0
	github.com/valyala/fasttemplate v1.2.1
	go.etcd.io/bbolt v1.3.6
	golang.org/x/net v0.0.0-20220127200216-cd36cc0744dd
	google.golang.org/grpc v1.42.0
	gopkg.in/AlecAivazis/survey.v1 v1.8.7
	gopkg.in/resty.v1 v1.12.0
	gopkg.in/yaml.v2 v2.4.0
	rsc.io/goversion v1.2.0
)

require github.com/openziti/channel v0.18.5

require (
	github.com/AppsFlyer/go-sundheit v0.5.0 // indirect
	github.com/MichaelMure/go-term-text v0.3.1 // indirect
	github.com/PuerkitoBio/purell v1.1.1 // indirect
	github.com/PuerkitoBio/urlesc v0.0.0-20170810143723-de5bf2ad4578 // indirect
	github.com/antlr/antlr4/runtime/Go/antlr v0.0.0-20211106181442-e4c1a74c66bd // indirect
	github.com/asaskevich/govalidator v0.0.0-20200907205600-7a23bdc65eef // indirect
	github.com/biogo/store v0.0.0-20200525035639-8c94ae1e7c9c // indirect
	github.com/cenkalti/backoff/v4 v4.1.2 // indirect
	github.com/cheekybits/genny v1.0.0 // indirect
	github.com/coreos/go-iptables v0.6.0 // indirect
	github.com/danwakefield/fnmatch v0.0.0-20160403171240-cbb64ac3d964 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/dgryski/dgoogauth v0.0.0-20190221195224-5a805980a5f3 // indirect
	github.com/disintegration/imaging v1.6.2 // indirect
	github.com/dlclark/regexp2 v1.4.0 // indirect
	github.com/docker/go-units v0.4.0 // indirect
	github.com/ef-ds/deque v1.0.4 // indirect
	github.com/eliukblau/pixterm/pkg/ansimage v0.0.0-20191210081756-9fb6cf8c2f75 // indirect
	github.com/emirpasic/gods v1.12.0 // indirect
	github.com/felixge/httpsnoop v1.0.1 // indirect
	github.com/fsnotify/fsnotify v1.5.1 // indirect
	github.com/go-ole/go-ole v1.2.6 // indirect
	github.com/go-openapi/analysis v0.20.1 // indirect
	github.com/go-openapi/errors v0.20.2 // indirect
	github.com/go-openapi/jsonpointer v0.19.5 // indirect
	github.com/go-openapi/jsonreference v0.19.6 // indirect
	github.com/go-openapi/loads v0.21.0 // indirect
	github.com/go-openapi/spec v0.20.4 // indirect
	github.com/go-openapi/swag v0.21.1 // indirect
	github.com/go-openapi/validate v0.20.3 // indirect
	github.com/go-stack/stack v1.8.0 // indirect
	github.com/go-task/slim-sprig v0.0.0-20210107165309-348f09dbbbc0 // indirect
	github.com/golang-jwt/jwt v3.2.2+incompatible // indirect
	github.com/gomarkdown/markdown v0.0.0-20191123064959-2c17d62f5098 // indirect
	github.com/google/uuid v1.3.0 // indirect
	github.com/gorilla/handlers v1.5.1 // indirect
	github.com/gorilla/mux v1.8.0 // indirect
	github.com/gorilla/websocket v1.4.2 // indirect
	github.com/hashicorp/golang-lru v0.5.4 // indirect
	github.com/hashicorp/hcl v1.0.0 // indirect
	github.com/inconshreveable/mousetrap v1.0.0 // indirect
	github.com/jessevdk/go-flags v1.5.0 // indirect
	github.com/jinzhu/copier v0.3.5 // indirect
	github.com/josharian/intern v1.0.0 // indirect
	github.com/josharian/native v1.0.0 // indirect
	github.com/kataras/go-events v0.0.3-0.20201007151548-c411dc70c0a6 // indirect
	github.com/kballard/go-shellquote v0.0.0-20180428030007-95032a82bc51 // indirect
	github.com/kr/pty v1.1.8 // indirect
	github.com/kyokomi/emoji/v2 v2.2.8 // indirect
	github.com/lucas-clemente/quic-go v0.23.0 // indirect
	github.com/lucasb-eyer/go-colorful v1.0.3 // indirect
	github.com/lucsky/cuid v1.2.1 // indirect
	github.com/magiconair/properties v1.8.5 // indirect
	github.com/mailru/easyjson v0.7.7 // indirect
	github.com/marten-seemann/qtls-go1-16 v0.1.4 // indirect
	github.com/marten-seemann/qtls-go1-17 v0.1.0 // indirect
	github.com/mattn/go-colorable v0.1.12 // indirect
	github.com/mattn/go-isatty v0.0.14 // indirect
	github.com/mattn/go-runewidth v0.0.12 // indirect
	github.com/mdlayher/netlink v1.6.0 // indirect
	github.com/mdlayher/socket v0.1.1 // indirect
	github.com/mgutz/ansi v0.0.0-20200706080929-d51e80ef957d // indirect
	github.com/miekg/dns v1.1.45 // indirect
	github.com/miekg/pkcs11 v1.1.1 // indirect
	github.com/mitchellh/go-ps v1.0.0 // indirect
	github.com/mitchellh/mapstructure v1.4.3 // indirect
	github.com/natefinch/lumberjack v2.0.0+incompatible // indirect
	github.com/netfoundry/secretstream v0.1.2 // indirect
	github.com/nxadm/tail v1.4.8 // indirect
	github.com/oklog/ulid v1.3.1 // indirect
	github.com/onsi/ginkgo v1.16.4 // indirect
	github.com/opentracing/opentracing-go v1.2.0 // indirect
	github.com/openziti/dilithium v0.3.3 // indirect
	github.com/orcaman/concurrent-map v0.0.0-20210106121528-16402b402231 // indirect
	github.com/parallaxsecond/parsec-client-go v0.0.0-20220111122524-cb78842db373 // indirect
	github.com/pelletier/go-toml v1.9.4 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/skip2/go-qrcode v0.0.0-20200617195104-da1b6568686e // indirect
	github.com/speps/go-hashids v2.0.0+incompatible // indirect
	github.com/spf13/afero v1.6.0 // indirect
	github.com/spf13/cast v1.4.1 // indirect
	github.com/spf13/jwalterweatherman v1.1.0 // indirect
	github.com/subosito/gotenv v1.2.0 // indirect
	github.com/teris-io/shortid v0.0.0-20201117134242-e59966efd125 // indirect
	github.com/tklauser/go-sysconf v0.3.9 // indirect
	github.com/tklauser/numcpus v0.3.0 // indirect
	github.com/valyala/bytebufferpool v1.0.0 // indirect
	github.com/xeipuuv/gojsonpointer v0.0.0-20180127040702-4e3ac2762d5f // indirect
	github.com/xeipuuv/gojsonreference v0.0.0-20180127040603-bd5ef7bd5415 // indirect
	github.com/xeipuuv/gojsonschema v1.2.0 // indirect
	github.com/yusufpapurcu/wmi v1.2.2 // indirect
	go.mongodb.org/mongo-driver v1.7.5 // indirect
	go.mozilla.org/pkcs7 v0.0.0-20200128120323-432b2356ecb1 // indirect
	golang.org/x/crypto v0.0.0-20220131195533-30dcbda58838 // indirect
	golang.org/x/image v0.0.0-20191206065243-da761ea9ff43 // indirect
	golang.org/x/mod v0.5.1 // indirect
	golang.org/x/sync v0.0.0-20210220032951-036812b2e83c // indirect
	golang.org/x/sys v0.0.0-20220128215802-99c3d69c2c27 // indirect
	golang.org/x/term v0.0.0-20210927222741-03fcf44c2211 // indirect
	golang.org/x/text v0.3.7 // indirect
	golang.org/x/tools v0.1.7 // indirect
	golang.org/x/xerrors v0.0.0-20200804184101-5ec99f83aff1 // indirect
	google.golang.org/genproto v0.0.0-20211208223120-3a66f561d7aa // indirect
	google.golang.org/protobuf v1.27.1 // indirect
	gopkg.in/ini.v1 v1.66.2 // indirect
	gopkg.in/square/go-jose.v2 v2.5.1 // indirect
	gopkg.in/tomb.v1 v1.0.0-20141024135613-dd632973f1e7 // indirect
	gopkg.in/yaml.v3 v3.0.0-20210107192922-496545a6307b // indirect
)

require (
	github.com/jedib0t/go-pretty/v6 v6.2.4
	github.com/rivo/uniseg v0.2.0 // indirect
)
