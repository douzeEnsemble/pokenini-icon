import pytest

import os
import sys
import shutil

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Util.FileDir import FileDir

class TestFileDir:

    def testCountFiles(self):
        assert 2 == FileDir.countFiles(current+'/resources/count_dir/two')
        assert 4 == FileDir.countFiles(current+'/resources/count_dir/four')

    def testRemoveFiles(self):
        try:
            os.mkdir(current+'/resources/count_dir/two_bis')
        except Exception:
            pass
        
        shutil.copy(
            current+'/resources/count_dir/two/one',
            current+'/resources/count_dir/two_bis'
        )
        shutil.copy(
            current+'/resources/count_dir/two/two',
            current+'/resources/count_dir/two_bis'
        )

        FileDir.removeFiles(current+'/resources/count_dir/two_bis')

        assert 0 == FileDir.countFiles(current+'/resources/count_dir/two_bis')

        os.rmdir(current+'/resources/count_dir/two_bis')
        
