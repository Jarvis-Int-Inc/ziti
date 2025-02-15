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

package subcmd

import (
	"fmt"
	"github.com/golang/protobuf/proto"
	"github.com/openziti/channel"
	"github.com/openziti/fabric/pb/mgmt_pb"
	"github.com/spf13/cobra"
	"time"
)

var createServiceClient *mgmtClient
var createServiceTerminatorStrategy string
var createServiceName string

func init() {
	createService.Flags().StringVar(&createServiceName, "name", "", "Service name. If not provided defaults to the ID")
	createService.Flags().StringVar(&createServiceTerminatorStrategy, "terminator-strategy", "", "Terminator strategy for service")
	createServiceClient = NewMgmtClient(createService)
	createCmd.AddCommand(createService)
}

var createService = &cobra.Command{
	Use:   "service <serviceId>",
	Short: "Create a new fabric service",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if ch, err := createServiceClient.Connect(); err == nil {
			request := &mgmt_pb.CreateServiceRequest{
				Service: &mgmt_pb.Service{
					Id:                 args[0],
					Name:               createServiceName,
					TerminatorStrategy: createServiceTerminatorStrategy,
				},
			}
			body, err := proto.Marshal(request)
			if err != nil {
				panic(err)
			}
			requestMsg := channel.NewMessage(int32(mgmt_pb.ContentType_CreateServiceRequestType), body)
			responseMsg, err := requestMsg.WithTimeout(5 * time.Second).SendForReply(ch)
			if err != nil {
				panic(err)
			}
			if responseMsg.ContentType == channel.ContentTypeResultType {
				result := channel.UnmarshalResult(responseMsg)
				if result.Success {
					fmt.Printf("\nsuccess\n\n")
				} else {
					fmt.Printf("\nfailure [%s]\n\n", result.Message)
				}
			} else {
				panic(fmt.Errorf("unexpected response type %v", responseMsg.ContentType))
			}
		} else {
			panic(err)
		}
	},
}
