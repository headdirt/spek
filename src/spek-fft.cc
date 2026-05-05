#include <cmath>

#define __STDC_CONSTANT_MACROS
extern "C" {
#include <libavutil/mem.h>
#include <libavutil/tx.h>
}

#include "spek-fft.h"

class FFTPlanImpl : public FFTPlan
{
public:
    FFTPlanImpl(int nbits);
    ~FFTPlanImpl() override;

    void execute() override;

private:
    AVTXContext *ctx;
    av_tx_fn fn;
    AVComplexFloat *out;
};

std::unique_ptr<FFTPlan> FFT::create(int nbits)
{
    return std::unique_ptr<FFTPlan>(new FFTPlanImpl(nbits));
}

FFTPlanImpl::FFTPlanImpl(int nbits) :
    FFTPlan(nbits), ctx(nullptr), fn(nullptr), out(nullptr)
{
    int len = 1 << nbits;
    float scale = 1.0f;
    av_tx_init(&this->ctx, &this->fn, AV_TX_FLOAT_RDFT, 0, len, &scale, 0);
    this->out = (AVComplexFloat*) av_malloc(sizeof(AVComplexFloat) * (len / 2 + 1));
}

FFTPlanImpl::~FFTPlanImpl()
{
    av_tx_uninit(&this->ctx);
    av_freep(&this->out);
}

void FFTPlanImpl::execute()
{
    this->fn(this->ctx, this->out, this->get_input(), sizeof(float));

    int n = this->get_input_size();
    float n2 = n * n;
    for (int i = 0; i <= n / 2; i++) {
        float re = this->out[i].re;
        float im = this->out[i].im;
        this->set_output(i, 10.0f * log10f((re * re + im * im) / n2));
    }
}
