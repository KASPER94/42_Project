learn2slither) ➜  learn2slither git:(main) python -c "import torch; print('TORCH OK, torch.randn(2).sum())"
  File "<string>", line 1
    import torch; print('TORCH OK, torch.randn(2).sum())
                        ^
SyntaxError: unterminated string literal (detected at line 1)
(learn2slither) ➜  learn2slither git:(main) python -c "import torch; print('TORCH OK', torch.randn(2).sum())"
TORCH OK tensor(-0.0703)
(learn2slither) ➜  learn2slither git:(main) PYTHONFAULTHANDLER=1 ./snake 
/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/pygame/pkgdata.py:25: UserWarning: pkg_resources is deprecated as an API. See https://setuptools.pypa.io/en/latest/pkg_resources.html. The pkg_resources package is slated for removal as early as 2025-11-30. Refrain from using this package or pin to Setuptools<81.
  from pkg_resources import resource_stream, resource_exists
Fatal Python error: Segmentation fault

Current thread 0x00007fcf59a25f00 (most recent call first):
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1317 in create_module
  File "<frozen importlib._bootstrap>", line 813 in module_from_spec
  File "<frozen importlib._bootstrap>", line 921 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/triton/knobs.py", line 15 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap>", line 1423 in _handle_fromlist
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/triton/runtime/autotuner.py", line 11 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/triton/runtime/__init__.py", line 1 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/triton/__init__.py", line 8 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/utils/_triton.py", line 10 in has_triton_package
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_dynamo/utils.py", line 2716 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_dynamo/exc.py", line 44 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_dynamo/symbolic_convert.py", line 54 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_dynamo/convert_frame.py", line 62 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_dynamo/aot_compile.py", line 17 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap>", line 1423 in _handle_fromlist
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_dynamo/__init__.py", line 13 in <module>
  File "<frozen importlib._bootstrap>", line 488 in _call_with_frames_removed
  File "<frozen importlib._bootstrap_external>", line 1023 in exec_module
  File "<frozen importlib._bootstrap>", line 935 in _load_unlocked
  File "<frozen importlib._bootstrap>", line 1331 in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 1360 in _find_and_load
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/_compile.py", line 47 in inner
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/optim/optimizer.py", line 405 in __init__
  File "/sgoinfre/goinfre/Perso/skapersk/learn2slither/.venv/lib64/python3.13/site-packages/torch/optim/adam.py", line 102 in __init__
  File "/sgoinfre/goinfre/Perso/skapersk/test/learn2slither/src/learn2slither/dqn_agent.py", line 159 in __init__

Extension modules: numpy._core._multiarray_umath, numpy.linalg._umath_linalg, pygame.base, pygame.constants, pygame.rect, pygame.rwobject, pygame.surflock, pygame.bufferproxy, pygame.math, pygame.surface, pygame.display, pygame.draw, pygame.event, pygame.imageext, pygame.image, pygame.joystick, pygame.key, pygame.mouse, pygame.time, pygame.mask, pygame.pixelcopy, pygame.transform, pygame.font, pygame.mixer_music, pygame.mixer, pygame.scrap, pygame._freetype, numpy.random._common, numpy.random.bit_generator, numpy.random._bounded_integers, numpy.random._pcg64, numpy.random._generator, numpy.random._mt19937, numpy.random._philox, numpy.random._sfc64, numpy.random.mtrand, torch._C, torch._C._dynamo.autograd_compiler, torch._C._dynamo.eval_frame, torch._C._dynamo.guards, torch._C._dynamo.utils, torch._C._fft, torch._C._linalg, torch._C._nested, torch._C._nn, torch._C._sparse, torch._C._special, cuda.bindings._bindings.cydriver, cuda.bindings.cydriver, cuda.bindings.driver, cuda.bindings._bindings.cyruntime_ptds, cuda.bindings._bindings.cyruntime, cuda.bindings.cyruntime, cuda.bindings.runtime (total: 54)
[1]    351572 segmentation fault (core dumped)  PYTHONFAULTHANDLER=1 ./snake