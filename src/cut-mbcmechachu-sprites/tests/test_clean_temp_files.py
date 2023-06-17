import os
import sys
from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Util.FileDir import FileDir
from module.Service.CleanTempFilesService import CleanTempFilesService

class TestCleanTempFiles:

    def testClean(self):
        self.__prepare()

        cleanTempFilesService = CleanTempFilesService('config.test.ini')
        cleanTempFilesService.clean()

        assert False == Path('temp/test-sprites').is_dir()
        assert False == Path('temp/test-sprites-split').is_dir()
        assert False == Path('temp/test-number').is_dir()
        assert False == Path('temp/test-clean-icon').is_dir()
        # Must not be remove
        assert True == Path('temp/test-final').is_dir()

        assert False == Path('temp/image.png').is_file()
        
        # Test cleaning
        FileDir.removeDir('temp/test-final')

    def __prepare(self):
        self.__prepareDir('temp/test-sprites')
        self.__prepareDir('temp/test-sprites-split')
        self.__prepareDir('temp/test-number')
        self.__prepareDir('temp/test-clean-icon')
        self.__prepareDir('temp/test-final')

        file = open('temp/image.png', 'a')
        file.write('Touch')
        file.close()

    def __prepareDir(self, dir):
        try:
            os.mkdir(dir)
        except Exception:
            pass

        file = open(dir+'/touch.txt', 'a')
        file.write('Touch')
        file.close()