#include <util/Worker.hpp>
#include <util/ThreadCollection.hpp>
#include <util/Job.hpp>

Worker::Worker(ThreadCollection& a2) {
	this->threadCollection = &a2;
}
void Worker::operator()(void) {
	ThreadCollection* tc = this->threadCollection;

	while(true) {
		std::shared_ptr<Job> el;
		{
			// Single lock guarding both the stop flag and the queue. Using a predicate
			// wait avoids the lost-wakeup / race that existed before (checking empty()
			// and wait() without holding the mutex).
			std::unique_lock<std::mutex> lock(tc->mutex);
			tc->field_64.wait(lock, [tc]{ return tc->isStopped || !tc->field_C.empty(); });

			if(tc->isStopped && tc->field_C.empty()) {
				break;
			}
			if(tc->field_C.empty()) {
				continue;
			}
			el = tc->field_C.front();
			tc->field_C.pop_front();
		}

		if(el.get()) {
			el->run();
			if(el->getStatus() == JS_FINISHED) {
				std::unique_lock<std::mutex> done(tc->field_60);
				tc->field_34.emplace_back(el);
			}
		}
	}
}
