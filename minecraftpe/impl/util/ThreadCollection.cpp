#include <util/ThreadCollection.hpp>
#include <util/Job.hpp>
#include <unistd.h>
#include <util/Worker.hpp>

static int sub_D66E4980() {
	int v0; // r0
	v0 = sysconf(97);
	return v0 & ~(v0 >> 31);
}
ThreadCollection::ThreadCollection(uint32_t maxthreads) {

	this->isStopped = 0;
	if(maxthreads == 0) {
		int v4 = sub_D66E4980();
		if(v4) maxthreads = v4;
		else maxthreads = 1;
	}

	for(unsigned int i = 0; i != maxthreads; ++i) {
			this->threads.emplace_back(std::thread(Worker(*this)));
	}
}
void ThreadCollection::enqueue(std::shared_ptr<Job> a2) {
	{
		std::lock_guard<std::mutex> lock(this->mutex);
		this->field_C.emplace_back(a2);
	}
	this->field_64.notify_one();
}
void ThreadCollection::processUIThread() {
	// Move the finished-jobs queue out under the lock, then run finish() callbacks
	// outside the lock. finish() may touch UI/connector state, so we must not hold
	// field_60 while calling it (and the previous version iterated/erased the deque
	// with no locking at all, racing the worker threads that push into field_34).
	std::deque<std::shared_ptr<Job>> done;
	{
		std::lock_guard<std::mutex> lock(this->field_60);
		done.swap(this->field_34);
	}
	for(auto&& job : done) {
		if(job.get() && job->status == JS_FINISHED) {
			job->finish();
		}
	}
}
ThreadCollection::~ThreadCollection() {
	{
		// Real lock (the old code created unnamed temporary unique_locks that were
		// destroyed immediately and therefore held nothing). Set the stop flag under
		// the mutex so the predicate wait in the workers observes it, then wake all.
		std::lock_guard<std::mutex> lock(this->mutex);
		this->isStopped = 1;
	}
	this->field_64.notify_all();

	for(auto&& t: this->threads) {
		if(t.joinable()) t.join();
	}
	this->threads.clear();

	{
		std::lock_guard<std::mutex> lock(this->field_60);
		this->field_34.clear();
	}
}
