import pytest
import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Service.CompareDirToListService import CompareDirToListService

class TestCompareDirToList:
    def test_compare(self):
        service = CompareDirToListService('config.test.ini') 

        exepectedList = [
            'venusaur-f',
        ]

        assert exepectedList == service.compare(
            current+'/resources/compare_dir_to_list/icons', 
            current+'/resources/compare_dir_to_list/some.csv'
        )

    def test_compare_empty_list(self):
        service = CompareDirToListService('config.test.ini') 

        exepectedList = []

        assert exepectedList == service.compare(
            current+'/resources/compare_dir_to_list/icons', 
            current+'/resources/compare_dir_to_list/empty.csv'
        )

    def test_compare_empty_dir(self):
        service = CompareDirToListService('config.test.ini') 

        exepectedList = [
            'bulbasaur', 
            'ivysaur', 
            'venusaur', 
            'venusaur-f',
        ]

        assert exepectedList == service.compare(
            current+'/resources/compare_dir_to_list/empty', 
            current+'/resources/compare_dir_to_list/some.csv'
        )

    def test_compare_list_not_exists(self):
        service = CompareDirToListService('config.test.ini') 

        with pytest.raises(Exception) as e:
            service.compare(
                current+'/resources/compare_dir_to_list/icon', 
                'nexiste.pas.csv'
            )

    def test_compare_dir_not_exists(self):
        service = CompareDirToListService('config.test.ini') 

        with pytest.raises(Exception) as e:
            service.compare('/nexiste/pas', current+'/resources/compare_dir_to_list/some.csv')

    def test_bad_config(self):
        with pytest.raises(Exception) as e:
            CompareDirToListService('nexiste.pas.ini') 