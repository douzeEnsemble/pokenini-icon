import pytest
import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Entity.Config.TypedConfig import TypedConfig

class TestTypedConfig:
    def test_init(self):
        typedConfig = TypedConfig('config.test.ini', 'regular')

        assert 'tests/resources/images/regulars.png' == typedConfig.resource_file
        assert 'tests/resources/list/pokemons-list.csv' == typedConfig.list_file
        assert 'regular' == typedConfig.output_dir

    def test_type_not_defined(self):
        with pytest.raises(Exception) as e:
            TypedConfig('config.test.ini', 'douze')

    def test_file_dont_exists(self):
        with pytest.raises(Exception) as e:
            TypedConfig('config.notexists.ini', 'regular')