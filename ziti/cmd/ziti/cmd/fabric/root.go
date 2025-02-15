/*
	Copyright NetFoundry, Inc.

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	https://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/

package fabric

import (
	"github.com/Jeffail/gabs"
	"github.com/openziti/ziti/ziti/cmd/ziti/cmd/api"
	"github.com/openziti/ziti/ziti/cmd/ziti/cmd/common"
	cmdhelper "github.com/openziti/ziti/ziti/cmd/ziti/cmd/helpers"
	"github.com/openziti/ziti/ziti/cmd/ziti/util"
	"github.com/spf13/cobra"
	"gopkg.in/resty.v1"
)

// NewFabricCmd creates a command object for the fabric command
func NewFabricCmd(p common.OptionsProvider) *cobra.Command {
	fabricCmd := util.NewEmptyParentCmd("fabric", "Interact with Ziti Fabric Components")

	fabricCmd.AddCommand(newAddIdentityCmd(p), newRemoveIdentityCmd(p))
	fabricCmd.AddCommand(newCreateCommand(p), newListCmd(p), newUpdateCommand(p), newDeleteCmd(p))
	fabricCmd.AddCommand(newInspectCmd(p))
	return fabricCmd
}

func newCreateCommand(p common.OptionsProvider) *cobra.Command {
	createCmd := &cobra.Command{
		Use:   "create",
		Short: "creates various entities managed by the Ziti Controller",
		Run: func(cmd *cobra.Command, args []string) {
			cmdhelper.CheckErr(cmd.Help())
		},
	}

	createCmd.AddCommand(newCreateRouterCmd(p))
	createCmd.AddCommand(newCreateServiceCmd(p))
	createCmd.AddCommand(newCreateTerminatorCmd(p))

	return createCmd
}

func newUpdateCommand(p common.OptionsProvider) *cobra.Command {
	updateCmd := &cobra.Command{
		Use:   "update",
		Short: "update various entities managed by the Ziti Controller",
		Run: func(cmd *cobra.Command, args []string) {
			cmdhelper.CheckErr(cmd.Help())
		},
	}

	updateCmd.AddCommand(newUpdateLinkCmd(p))
	updateCmd.AddCommand(newUpdateRouterCmd(p))
	updateCmd.AddCommand(newUpdateServiceCmd(p))
	updateCmd.AddCommand(newUpdateTerminatorCmd(p))

	return updateCmd
}

// createEntityOfType create an entity of the given type on the Ziti Controller
func createEntityOfType(entityType string, body string, options *api.Options) (*gabs.Container, error) {
	return util.ControllerCreate("fabric", entityType, body, options.Out, options.OutputJSONRequest, options.OutputJSONResponse, options.Timeout, options.Verbose)
}

func patchEntityOfType(entityType string, body string, options *api.Options) (*gabs.Container, error) {
	return updateEntityOfType(entityType, body, options, resty.MethodPatch)
}

// updateEntityOfType updates an entity of the given type on the Ziti Edge Controller
func updateEntityOfType(entityType string, body string, options *api.Options, method string) (*gabs.Container, error) {
	return util.ControllerUpdate(util.FabricAPI, entityType, body, options.Out, method, options.OutputJSONRequest, options.OutputJSONResponse, options.Timeout, options.Verbose)
}
