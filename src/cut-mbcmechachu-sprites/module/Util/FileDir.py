import os
import shutil
from pathlib import Path

class FileDir:
    @staticmethod
    def countFiles(dir: str) -> int:
        count = 0
        for rootDir, curDir, files in os.walk(dir):
            count += len(files)

        return count
    
    @staticmethod
    def countFilesWithExtension(dir: str, ext: str) -> int:
        count = 0
        for rootDir, curDir, files in os.walk(dir):
            for file in files:
                path = Path(file)

                if (path.suffix == ext):
                    count += 1

        return count
    
    @staticmethod
    def removeFiles(dir):
        FileDir.removeDir(dir)

        os.mkdir(dir)
    
    @staticmethod
    def removeDir(dir):
        if os.path.isdir(dir):
            shutil.rmtree(dir)

    @staticmethod
    def createDirs(dirs):
        Path.mkdir(Path(dirs), parents=True, exist_ok=True)