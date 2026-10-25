# Steps to build for ARMHF platform

1. Create nfs2se-build image:
```
docker build --platform linux/armhf -t nfs2se-build -f Dockerfile.armhf .
```

2. Run container from the image (replace `/path/to/NFSIISE` by the path of the NFSIISE directory):
```
docker run -it --name nfs2se-build -v "/path/to/NFSIISE:/src" nfs2se-build
```

3. Inside the container, Compile and install SDL2 dependency:
```
bash build_sdl2_armhf.sh
```

4. Still inside the container, compile nfs:
```
./compile_nfs cpp gles2
```
