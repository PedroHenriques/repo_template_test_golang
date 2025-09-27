//go:build Unit

package utils_test

import (
	"testing"

	utils "github.com/PedroHenriques/golang_ms_template/Api/internal"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

type utilsTestSuite struct {
	suite.Suite
	testMsg string
}

func (suite *utilsTestSuite) SetupTest() {
	suite.testMsg = "Golang"
}

func (suite *utilsTestSuite) TestHelloItShouldReturnTheExpectedString() {
	assert.Equal(suite.T(), "Hello Golang", utils.Hello(suite.testMsg))
}

func TestUtilsTestSuite(t *testing.T) {
	suite.Run(t, new(utilsTestSuite))
}