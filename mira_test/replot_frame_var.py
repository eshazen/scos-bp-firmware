
import matplotlib.pyplot as plt
import numpy as np

fnames = [  "20260506_093131-1ms-RAW8-240",
            "20260506_142637-1ms-RAW10-240", 
            "20260506_124941-1ms-RAW12-240"]

# fnames = [  "20260506_093131-1ms-RAW8-240",
#             "20260506_000635-1ms-RAW8-240",
#             "20260506_142637-1ms-RAW10-240",
#             "20260506_141111-1ms-RAW10-240", 
#             "20260506_124941-1ms-RAW12-240",
#             "20260506_123607-1ms-RAW12-240"]

for ifile in range(len(fnames)):
    fname = fnames[ifile]
    img_data_stack = np.load(f"./meas/{fname}.npy")
    mean_img = np.mean(img_data_stack, axis=0, keepdims=False)
    var_img = np.var(img_data_stack, axis=0, keepdims=False)

    mean_of_mean = np.mean(mean_img.flatten())
    var_of_mean = np.var(mean_img.flatten())
    mean_of_var = np.mean(var_img.flatten())

    n_frames = fname.split('-')[3]
    pix_format = fname.split('-')[2]
    file_desc = fname.split('-')[1]

    plt.hist(var_img.flatten(), np.arange(0,10,0.02), label=pix_format)
    xmin, xmax = plt.xlim()
    plt.ylim(0,8e4)
    ymin, ymax = plt.ylim() 
    plt.text(xmin+0.6*(xmax-xmin), (0.8-0.1*ifile)*ymax, f"{pix_format} mean: {mean_of_var:.2f}")

plt.text(xmin+0.6*(xmax-xmin), (0.8-0.1*len(fnames))*ymax, f"nFrames: {n_frames} ea")
plt.xlabel('var(Digital Level)')
plt.grid(visible=True, alpha=0.2)
plt.title(f'Pixel Temporal Variance Histogram')  
plt.savefig(f"./meas/Bitdepth_Comp.png", dpi=200)
# plt.legend()
plt.show()

