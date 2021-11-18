// Copyright (c) 2021 Doc.ai and/or its affiliates.
//
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package test

import (
	"flag"
	"os"
	"testing"

	"github.com/networkservicemesh/integration-tests/suites/interdomain"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

func TestInterdomainBasicSuite(t *testing.T) {
	require.NoError(t, flag.Set("gotestmd.t", "10m"))
	os.Setenv("KUBECONFIG", os.Getenv("KUBECONFIG1"))
	suite.Run(t, new(interdomain.Suite))
}
