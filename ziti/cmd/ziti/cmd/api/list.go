package api

import (
	"fmt"
	"github.com/Jeffail/gabs"
	"github.com/openziti/foundation/util/errorz"
	"github.com/openziti/ziti/ziti/cmd/ziti/util"
	"github.com/pkg/errors"
	"io"
	"net/url"
	"os"
	"reflect"
	"strings"
)

// ListEntitiesOfType queries the Ziti Controller for entities of the given type
func ListEntitiesWithOptions(api util.API, entityType string, options *Options) ([]*gabs.Container, *Paging, error) {
	params := url.Values{}
	if len(options.Args) > 0 {
		params.Add("filter", options.Args[0])
	}

	return ListEntitiesOfType(api, entityType, params, options.OutputJSONResponse, options.Out, options.Timeout, options.Verbose)
}

// ListEntitiesOfType queries the Ziti Controller for entities of the given type
func ListEntitiesOfType(api util.API, entityType string, params url.Values, logJSON bool, out io.Writer, timeout int, verbose bool) ([]*gabs.Container, *Paging, error) {
	jsonParsed, err := util.ControllerList(api, entityType, params, logJSON, out, timeout, verbose)

	if err != nil {
		return nil, nil, err
	}

	children, err := jsonParsed.S("data").Children()
	return children, getPaging(jsonParsed), err
}

func getPaging(c *gabs.Container) *Paging {
	pagingInfo := &Paging{}
	pagination := c.S("meta", "pagination")
	if pagination != nil {
		pagingInfo.limit = toInt64(pagination, "limit", pagingInfo)
		pagingInfo.offset = toInt64(pagination, "offset", pagingInfo)
		pagingInfo.count = toInt64(pagination, "totalCount", pagingInfo)
	} else {
		pagingInfo.SetError(errors.New("meta.pagination section not found in result"))
	}
	return pagingInfo
}

type Paging struct {
	limit  int64
	offset int64
	count  int64
	errorz.ErrorHolderImpl
}

func (p *Paging) Output(o *Options) {
	if p.HasError() {
		_, _ = fmt.Fprintf(o.Out, "unable to retrieve paging information: %v\n", p.Err)
	} else if p.count == 0 {
		_, _ = fmt.Fprintln(o.Out, "results: none")
	} else {
		first := p.offset + 1
		last := p.offset + p.limit
		if last > p.count || last < 0 { // if p.limit is maxint, last will rollover and be negative
			last = p.count
		}
		_, _ = fmt.Fprintf(o.Out, "results: %v-%v of %v\n", first, last, p.count)
	}
}

func toInt64(c *gabs.Container, path string, errorHolder errorz.ErrorHolder) int64 {
	data := c.S(path).Data()
	if data == nil {
		errorHolder.SetError(errors.Errorf("%v not found", path))
		return 0
	}
	val, ok := data.(float64)
	if !ok {
		errorHolder.SetError(errors.Errorf("%v not a number, it's a %v", path, reflect.TypeOf(data)))
		return 0
	}
	return int64(val)
}

func FilterEntitiesOfType(api util.API, entityType string, filter string, logJSON bool, out io.Writer, timeout int, verbose bool) ([]*gabs.Container, *Paging, error) {
	params := url.Values{}
	params.Add("filter", filter)
	return ListEntitiesOfType(api, entityType, params, logJSON, out, timeout, verbose)
}

func MapNameToID(api util.API, entityType string, o *Options, idOrName string) (string, error) {
	result, err := MapNamesToIDs(api, entityType, o, idOrName)
	if err != nil {
		return "", err
	}
	if len(result) != 1 {
		return "", errors.Errorf("found %v results for input %v when mapping %v to id", len(result), idOrName, entityType)
	}
	return result[0], nil
}

func MapNamesToIDs(api util.API, entityType string, o *Options, list ...string) ([]string, error) {
	var result []string
	for _, val := range list {
		if strings.HasPrefix(val, "id") {
			id := strings.TrimPrefix(val, "id:")
			result = append(result, id)
		} else {
			query := fmt.Sprintf(`id = "%s" or name="%s"`, val, val)
			if strings.HasPrefix(val, "name") {
				name := strings.TrimPrefix(val, "name:")
				query = fmt.Sprintf(`name="%s"`, name)
			}
			list, _, err := FilterEntitiesOfType(api, entityType, query, false, nil, o.Timeout, o.Verbose)
			if err != nil {
				return nil, err
			}

			if len(list) > 1 {
				fmt.Printf("Found multiple %v matching %v. Please specify which you want by prefixing with id: or name:\n", entityType, val)
				return nil, errors.Errorf("ambigous if %v is id or name", val)
			}

			for _, entity := range list {
				entityId, _ := entity.Path("id").Data().(string)
				result = append(result, entityId)
				if val, found := os.LookupEnv("ZITI_CLI_DEBUG"); found && strings.EqualFold("true", val) {
					fmt.Printf("Found %v with id %v for name %v\n", entityType, entityId, val)
				}
			}
		}
	}
	return result, nil
}
