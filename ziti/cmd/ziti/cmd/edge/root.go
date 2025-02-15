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

package edge

import (
	"github.com/openziti/ziti/common/enrollment"
	"io"

	"github.com/openziti/ziti/ziti/cmd/ziti/cmd/common"
	cmdutil "github.com/openziti/ziti/ziti/cmd/ziti/cmd/factory"
	"github.com/openziti/ziti/ziti/cmd/ziti/util"
	"github.com/spf13/cobra"
)

// NewCmdEdge creates a command object for the "controller" command
func NewCmdEdge(f cmdutil.Factory, out io.Writer, errOut io.Writer) *cobra.Command {
	cmd := util.NewEmptyParentCmd("edge", "Interact with Ziti Edge Components")
	populateEdgeCommands(f, out, errOut, cmd)
	return cmd
}

func populateEdgeCommands(f cmdutil.Factory, out io.Writer, errOut io.Writer, cmd *cobra.Command) *cobra.Command {
	p := common.NewOptionsProvider(out, errOut)
	cmd.AddCommand(newCreateCmd(f, out, errOut))
	cmd.AddCommand(newDeleteCmd(out, errOut))
	cmd.AddCommand(newLoginCmd(out, errOut))
	cmd.AddCommand(newLogoutCmd(out, errOut))
	cmd.AddCommand(newUseCmd(out, errOut))
	cmd.AddCommand(newListCmd(out, errOut))
	cmd.AddCommand(newUpdateCmd(f, out, errOut))
	cmd.AddCommand(newVersionCmd(out, errOut))
	cmd.AddCommand(newPolicyAdivsorCmd(out, errOut))
	cmd.AddCommand(newVerifyCmd(out, errOut))
	cmd.AddCommand(newDbCmd(out, errOut))
	cmd.AddCommand(enrollment.NewEnrollCommand())
	cmd.AddCommand(newTraceCmd(out, errOut))
	cmd.AddCommand(newTutorialCmd(p))
	cmd.AddCommand(newTraceRouteCmd(out, errOut))
	return cmd
}
