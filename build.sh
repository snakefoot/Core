#!/bin/bash
# ****************************************************************************
# Copyright 2004-2022 Castle Project - http://www.castleproject.org/
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ****************************************************************************
shopt -s expand_aliases

DOTNETPATH=$(which dotnet)
if [ ! -f "$DOTNETPATH" ]; then
	echo "Please install Microsoft/netcore from: https://www.microsoft.com/net/core"
	exit 1
fi

DOCKERPATH=$(which docker)
if [ -f "$DOCKERPATH" ]; then
	alias mono="$PWD/buildscripts/docker-run-mono.sh"
else
	MONOPATH=$(which mono)
	if [ ! -f "$MONOPATH" ]; then
		echo "Please install either Docker, or Xamarin/Mono from http://www.mono-project.com/docs/getting-started/install/"
		exit 1
	fi
fi

mono --version

# Linux/Darwin
OSNAME=$(uname -s)
echo "OSNAME: $OSNAME"

dotnet build --configuration Release || exit 1

echo --------------------
echo Running NET462 Tests
echo --------------------

mono ./src/Castle.Core.Tests/bin/Release/net462/Castle.Core.Tests.exe --result=DesktopClrTestResults.xml;format=nunit3
mono ./src/Castle.Core.Tests.WeakNamed/bin/Release/net462/Castle.Core.Tests.WeakNamed.exe --result=DesktopClrWeakNamedTestResults.xml;format=nunit3

echo ---------------------------
echo Running NET6.0 Tests
echo ---------------------------

dotnet ./src/Castle.Core.Tests/bin/Release/net6.0/Castle.Core.Tests.dll --result=Net60TestResults.xml;format=nunit3
dotnet ./src/Castle.Core.Tests.WeakNamed/bin/Release/net6.0/Castle.Core.Tests.WeakNamed.dll --result=Net60WeakNamedTestResults.xml;format=nunit3

# Ensure that all test runs produced a protocol file:
if [[ !( -f Net60TestResults.xml &&
         -f Net60WeakNamedTestResults.xml &&
         -f DesktopClrTestResults.xml &&
         -f DesktopClrWeakNamedTestResults.xml ) ]]; then
    echo "Incomplete test results. Some test runs might not have terminated properly. Failing the build."
    exit 1
fi

# Unit test failure

NET60_FAILCOUNT=$(grep -F "One or more child tests had errors" Net60TestResults.xml Net60WeakNamedTestResults.xml | wc -l)
if [ $NET60_FAILCOUNT -ne 0 ]
then
    echo "Net6.0 Tests have failed, failing the build"
    exit 1
fi

MONO_FAILCOUNT=$(grep -F "One or more child tests had errors" DesktopClrTestResults.xml DesktopClrWeakNamedTestResults.xml | wc -l)
if [ $MONO_FAILCOUNT -ne 0 ]
then
    echo "DesktopClr Tests have failed, failing the build"
    exit 1
fi
