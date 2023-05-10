import os
import shutil

class FileDir:
    @staticmethod
    def countFiles(dir):
        count = 0
        for root_dir, cur_dir, files in os.walk(dir):
            count += len(files)

        return count
    
    @staticmethod
    def removeFiles(dir):
        shutil.rmtree(dir)
        os.mkdir(dir)