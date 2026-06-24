(learn2slither) ➜  learn2slither git:(main) LD_PRELOAD=/usr/lib64/libstdc++.so.6 ./snake
/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/pygame/pkgdata.py:25: UserWarning: pkg_resources is deprecated as an API. See https://setuptools.pypa.io/en/latest/pkg_resources.html. The pkg_resources package is slated for removal as early as 2025-11-30. Refrain from using this package or pin to Setuptools<81.
  from pkg_resources import resource_stream, resource_exists
[1]    348809 segmentation fault (core dumped)  LD_PRELOAD=/usr/lib64/libstdc++.so.6 ./snake
(learn2slither) ➜  learn2slither git:(main) ldconfig -p | grep libstdc++
	libstdc++.so.6 (libc6,x86-64) => /lib64/libstdc++.so.6
	libstdc++.so.6 (libc6) => /lib/libstdc++.so.6
(learn2slither) ➜  learn2slither git:(main) LIBGL_ALWAYS_SOFTWARE=1 ./snake
/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/pygame/pkgdata.py:25: UserWarning: pkg_resources is deprecated as an API. See https://setuptools.pypa.io/en/latest/pkg_resources.html. The pkg_resources package is slated for removal as early as 2025-11-30. Refrain from using this package or pin to Setuptools<81.
  from pkg_resources import resource_stream, resource_exists
[1]    349008 segmentation fault (core dumped)  LIBGL_ALWAYS_SOFTWARE=1 ./snake
(learn2slither) ➜  learn2slither git:(main) SDL_VIDEODRIVER=x11 ./snake   
/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/pygame/pkgdata.py:25: UserWarning: pkg_resources is deprecated as an API. See https://setuptools.pypa.io/en/latest/pkg_resources.html. The pkg_resources package is slated for removal as early as 2025-11-30. Refrain from using this package or pin to Setuptools<81.
  from pkg_resources import resource_stream, resource_exists
[1]    349176 segmentation fault (core dumped)  SDL_VIDEODRIVER=x11 ./snake
(learn2slither) ➜  learn2slither git:(main) LD_PRELOAD=/usr/lib64/libstdc++.so.6 LIBGL_ALWAYS_SOFTWARE=1 ./snake
/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/pygame/pkgdata.py:25: UserWarning: pkg_resources is deprecated as an API. See https://setuptools.pypa.io/en/latest/pkg_resources.html. The pkg_resources package is slated for removal as early as 2025-11-30. Refrain from using this package or pin to Setuptools<81.
  from pkg_resources import resource_stream, resource_exists
[1]    349314 segmentation fault (core dumped)  LD_PRELOAD=/usr/lib64/libstdc++.so.6 LIBGL_ALWAYS_SOFTWARE=1 ./snake
(learn2slither) ➜  learn2slither git:(main) 
